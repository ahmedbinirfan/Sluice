# Serving notes (SLU-52) — VRAM maths for Qwen3-8B-AWQ on a T4

GPU: `Standard_NC4as_T4_v3` — **16 GB** VRAM, no bf16. Model: `Qwen/Qwen3-8B-AWQ` (ADR-0004). Serve with vLLM, `dtype=float16`.

Config that matters (from `Qwen/Qwen3-8B` `config.json`):

| Field | Value |
| --- | --- |
| `num_hidden_layers` | 36 |
| `num_attention_heads` | 32 |
| `num_key_value_heads` | 8 (GQA) |
| `head_dim` | 128 |
| `hidden_size` | 4096 |

## Weights (4-bit AWQ)

Rough lower bound if every parameter were pure INT4: `8.2e9 × 0.5 B ≈ 4.1 GB`.

Real AWQ checkpoints add scales/zeros, plus CUDA context, activations, and vLLM workspace. On a 16 GB card, treat **weights + runtime overhead ≈ 8–9 GB**, and **budget ~7–8 GB for KV cache** (ADR-0004). Do not plan as if 12 GB of KV were free.

## KV cache per token (fp16 K and V)

For one token, store K and V for every layer, every KV head:

```
bytes/token = 2 × layers × kv_heads × head_dim × sizeof(fp16)
            = 2 × 36 × 8 × 128 × 2
            = 147,456 B
            ≈ 144 KiB/token
```

PagedAttention changes packing, not this order of magnitude.

## Concurrent 4k-context requests

One request at **4,096** tokens of KV (prompt + generation counted against the same budget for this napkin math):

```
4,096 × 147,456 B ≈ 604 MB ≈ 0.59 GB
```

If **~7.5 GB** is left for KV:

```
floor(7.5 / 0.59) ≈ 12 concurrent 4k requests
```

| max-model-len (tokens) | KV / request (GB) | Concurrent if 7.5 GB KV |
| --- | --- | --- |
| 2,048 | ~0.29 | ~25 |
| 4,096 | ~0.59 | ~12 |
| 8,192 | ~1.18 | ~6 |
| 32,768 | ~4.72 | ~1 |

So `--max-model-len` trades context length for concurrency. For Phase 1 smoke on one T4, prefer **4k–8k** unless a ticket needs the native 32k window.

## What to compare at vLLM startup (SLU-53)

After deploy, read the engine log for model load size and KV cache blocks / max concurrency. If measured KV budget is far below ~7 GB, lower `--gpu-memory-utilization` assumptions or `--max-model-len`, and update this file with the measured numbers.

## TEI on CPU (SLU-54)

Two TEI pods on the **system** pool (`ghcr.io/huggingface/text-embeddings-inference:cpu-1.9`):

| Service | Model | Smoke |
| --- | --- | --- |
| `sluice-tei-embed` | `BAAI/bge-base-en-v1.5` | `POST /embed` → 768-d vector |
| `sluice-tei-rerank` | `BAAI/bge-reranker-base` | `POST /rerank` → scores |

Measured wall time through port-forward on AKS (cold-ish after Ready, single short request, **CPU**):

- `/embed` ≈ **200 ms**
- `/rerank` (1 query, 2 texts) ≈ **160 ms**

GPU TEI would be faster; we stayed on CPU to keep the T4 free for vLLM and to fit the AUD 30 habit. Re-measure if models or node size change.

## LiteLLM gateway (SLU-55)

`gateway/config.yaml` registers three routes behind `sluice-litellm:4000`:

| Route model | Upstream |
| --- | --- |
| `qwen3-8b-awq` | `sluice-vllm:8000` (OpenAI chat) |
| `bge-base-en-v1.5` | `sluice-tei-embed` (OpenAI embeddings) |
| `bge-reranker-base` | `sluice-tei-rerank` (HF/TEI rerank) |

Master key and Postgres URL live in Key Vault (`litellm-master-key`, `litellm-postgres-password`), mirrored to Secret `sluice-litellm` via `scripts/sync-litellm-secrets.sh` — not in Git. Prove with the OpenAI Python SDK pointed at the gateway `base_url` (+ `/rerank` for the cross-encoder).

## KEDA on queue depth (SLU-56)

Scale on **waiting** requests, not GPU util: a busy GPU can still accept more work until the scheduler queue grows. KEDA scrapes Prometheus (`sluice-prometheus`) for `sum(vllm:num_requests_waiting)` and scales the vLLM **StatefulSet** (one PVC per replica so RWO cache works on a second spot node). GPU pool `max_count` is 2 so the second replica can schedule.

Observe under load: `make loadtest` while watching `kubectl -n sluice get sts,pods,hpa,scaledobject -w` and `kubectl get nodes -l pool=gpu -w`.

## Gateway smoke (SLU-57)

`make smoke` port-forwards the gateway, loads the master key from Key Vault, and runs `tests/test_smoke.py` (chat + embeddings + rerank with latency ceilings).
