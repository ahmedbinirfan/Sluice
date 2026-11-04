# ADR 0004: Which model to serve

## Status

Accepted

## Context

Sluice serves open weights on AKS spot `Standard_NC4as_T4_v3` nodes: one NVIDIA T4 with **16 GB VRAM** and **no bfloat16**. GPU memory, not FLOPs, sets how many concurrent requests fit. Phase 1 needs one 7–8B instruct model in **AWQ 4-bit**, served with **vLLM** using **`dtype=float16`**, that is good enough for smoke tests now and for tool-calling agents later.

## Decision

Use **`Qwen/Qwen3-8B-AWQ`** as Sluice’s base chat model.

- ~8.2B parameters, AWQ 4-bit.
- Native context **32,768** tokens (up to **131,072** with YaRN when we need it).
- **Apache 2.0** (commercial-friendly for a portfolio demo).
- Strong instruct + agent / tool-calling support; optional thinking mode for harder prompts.

Serve with vLLM (`>=0.8.5` per the model card). On the T4, keep **`dtype=float16`** — do not rely on bf16.

## Consequences

Set the weights (and vLLM memory flags) so **roughly 7–8 GB of the 16 GB stays free for KV cache**. Exact concurrency lands in SLU-52’s VRAM maths (`docs/learning/serving.md`).

**Thinking mode is off by default** for gateway and agent traffic (`enable_thinking=False` / equivalent vLLM chat-template setting). Default-on thinking burns tokens and latency on every call; turn it on only for explicit reasoning paths. Soft `/think` switches stay available when thinking is enabled for a route.

Model id and serve flags go in the vLLM Helm values (SLU-53). Changing the base model later is another ADR, **not a silent values edit**.

## Alternatives considered

**Meta Llama 3.1 8B Instruct AWQ** — also fits a T4 under AWQ + vLLM `float16`, with **128k** context. **Llama Community License** requires attribution and has use restrictions that are fine for a personal demo but noisier than Qwen for “ship this chart as-is.” Tool-calling is solid; no first-class thinking/non-thinking switch like Qwen3. Rejected as the default so Sluice stays on one Apache-friendly card with a clear agent story. **Not a hot-swap** if Qwen3 misbehaves — that would be a new ADR, not a silent values edit.
