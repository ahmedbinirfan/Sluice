#!/usr/bin/env python3
"""SLU-56: fire a concurrent chat burst through the gateway to deepen vLLM's wait queue."""

from __future__ import annotations

import argparse
import asyncio
import os
import time

import httpx

GATEWAY_URL = os.environ.get("SLUICE_GATEWAY_URL", "http://127.0.0.1:4000").rstrip("/")
MASTER_KEY = os.environ.get("SLUICE_MASTER_KEY", "")


async def one_chat(client: httpx.AsyncClient, i: int) -> tuple[int, float, int]:
    started = time.perf_counter()
    resp = await client.post(
        "/v1/chat/completions",
        headers={"Authorization": f"Bearer {MASTER_KEY}"},
        json={
            "model": "qwen3-8b-awq",
            "messages": [{"role": "user", "content": f"Count slowly to 20 starting at {i}."}],
            "max_tokens": 128,
            "temperature": 0,
        },
    )
    return i, time.perf_counter() - started, resp.status_code


async def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--concurrency", type=int, default=16)
    parser.add_argument("--timeout", type=float, default=180.0)
    args = parser.parse_args()

    if not MASTER_KEY:
        raise SystemExit("SLUICE_MASTER_KEY is required")

    print(f"burst concurrency={args.concurrency} gateway={GATEWAY_URL}")
    async with httpx.AsyncClient(base_url=GATEWAY_URL, timeout=args.timeout) as client:
        results = await asyncio.gather(
            *[one_chat(client, i) for i in range(args.concurrency)],
            return_exceptions=True,
        )

    ok = 0
    for r in results:
        if isinstance(r, Exception):
            print("ERR", r)
            continue
        i, elapsed, status = r
        ok += int(200 <= status < 300)
        print(f"req={i} status={status} elapsed={elapsed:.1f}s")
    print(f"done ok={ok}/{args.concurrency}")


if __name__ == "__main__":
    asyncio.run(main())
