#!/usr/bin/env python3
"""SLU-56: deepen vllm:num_requests_waiting with overlapping long chat completions.

Default target is the LiteLLM gateway. Pass --direct-vllm to hit sluice-vllm
(useful when proving KEDA; the gateway may absorb concurrency).
"""

from __future__ import annotations

import argparse
import asyncio
import os
import time

import httpx

GATEWAY_URL = os.environ.get("SLUICE_GATEWAY_URL", "http://127.0.0.1:4000").rstrip("/")
MASTER_KEY = os.environ.get("SLUICE_MASTER_KEY", "")
VLLM_URL = os.environ.get("SLUICE_VLLM_URL", "http://127.0.0.1:8000").rstrip("/")


async def one_chat(
    client: httpx.AsyncClient, model: str, i: int, max_tokens: int
) -> tuple[int, float, int]:
    started = time.perf_counter()
    resp = await client.post(
        "/v1/chat/completions",
        json={
            "model": model,
            "messages": [
                {
                    "role": "user",
                    "content": (
                        f"Write a long detailed essay about Kubernetes autoscaling #{i}. "
                        "Include many paragraphs and keep going."
                    ),
                }
            ],
            "max_tokens": max_tokens,
            "temperature": 0,
        },
    )
    return i, time.perf_counter() - started, resp.status_code


async def wave(
    client: httpx.AsyncClient,
    *,
    model: str,
    concurrency: int,
    max_tokens: int,
    offset: int,
) -> list[object]:
    return await asyncio.gather(
        *[one_chat(client, model, offset + i, max_tokens) for i in range(concurrency)],
        return_exceptions=True,
    )


async def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--concurrency", type=int, default=32)
    parser.add_argument("--waves", type=int, default=3)
    parser.add_argument("--max-tokens", type=int, default=512)
    parser.add_argument("--timeout", type=float, default=300.0)
    parser.add_argument(
        "--direct-vllm",
        action="store_true",
        help="Hit vLLM directly (skip LiteLLM) to deepen the wait queue for KEDA.",
    )
    args = parser.parse_args()

    if args.direct_vllm:
        base = VLLM_URL
        model = "Qwen/Qwen3-8B-AWQ"
        headers: dict[str, str] = {}
    else:
        if not MASTER_KEY:
            raise SystemExit("SLUICE_MASTER_KEY is required (or pass --direct-vllm)")
        base = GATEWAY_URL
        model = "qwen3-8b-awq"
        headers = {"Authorization": f"Bearer {MASTER_KEY}"}

    print(
        f"burst concurrency={args.concurrency} waves={args.waves} "
        f"max_tokens={args.max_tokens} base={base}"
    )
    async with httpx.AsyncClient(
        base_url=base, timeout=args.timeout, headers=headers
    ) as client:
        for w in range(args.waves):
            print(f"wave={w} start", flush=True)
            results = await wave(
                client,
                model=model,
                concurrency=args.concurrency,
                max_tokens=args.max_tokens,
                offset=w * args.concurrency,
            )
            ok = 0
            for r in results:
                if isinstance(r, Exception):
                    print("ERR", r)
                    continue
                i, elapsed, status = r
                ok += int(200 <= status < 300)
                print(f"req={i} status={status} elapsed={elapsed:.1f}s")
            print(f"wave={w} done ok={ok}/{args.concurrency}", flush=True)
    print("done")


if __name__ == "__main__":
    asyncio.run(main())
