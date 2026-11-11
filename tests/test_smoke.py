"""SLU-57: gateway smoke — chat, embeddings, and rerank through LiteLLM."""

from __future__ import annotations

import os
import time

import httpx
import pytest
from openai import OpenAI

GATEWAY_URL = os.environ.get("SLUICE_GATEWAY_URL", "http://127.0.0.1:4000").rstrip("/")
MASTER_KEY = os.environ.get("SLUICE_MASTER_KEY", "")

# Generous ceilings: spot GPU cold start + TEI on a shared system node.
CHAT_LATENCY_S = float(os.environ.get("SLUICE_SMOKE_CHAT_S", "90"))
EMBED_LATENCY_S = float(os.environ.get("SLUICE_SMOKE_EMBED_S", "30"))
RERANK_LATENCY_S = float(os.environ.get("SLUICE_SMOKE_RERANK_S", "30"))


@pytest.fixture(scope="module")
def client() -> OpenAI:
    if not MASTER_KEY:
        pytest.skip("SLUICE_MASTER_KEY is not set")
    return OpenAI(base_url=f"{GATEWAY_URL}/v1", api_key=MASTER_KEY, timeout=CHAT_LATENCY_S)


def test_chat_through_gateway(client: OpenAI) -> None:
    started = time.perf_counter()
    resp = client.chat.completions.create(
        model="qwen3-8b-awq",
        messages=[{"role": "user", "content": "Reply with exactly: pong"}],
        max_tokens=32,
        temperature=0,
    )
    elapsed = time.perf_counter() - started
    assert resp.choices, "chat response missing choices"
    assert resp.choices[0].message.content, "chat response empty"
    assert elapsed < CHAT_LATENCY_S, f"chat took {elapsed:.1f}s (ceiling {CHAT_LATENCY_S}s)"


def test_embeddings_through_gateway(client: OpenAI) -> None:
    started = time.perf_counter()
    resp = client.embeddings.create(model="bge-base-en-v1.5", input="sluice smoke")
    elapsed = time.perf_counter() - started
    assert resp.data, "embeddings response empty"
    assert len(resp.data[0].embedding) == 768
    assert elapsed < EMBED_LATENCY_S, f"embed took {elapsed:.1f}s (ceiling {EMBED_LATENCY_S}s)"


def test_rerank_through_gateway() -> None:
    if not MASTER_KEY:
        pytest.skip("SLUICE_MASTER_KEY is not set")
    started = time.perf_counter()
    with httpx.Client(base_url=GATEWAY_URL, timeout=RERANK_LATENCY_S) as http:
        resp = http.post(
            "/rerank",
            headers={"Authorization": f"Bearer {MASTER_KEY}"},
            json={
                "model": "bge-reranker-base",
                "query": "capital of France",
                "documents": [
                    "Paris is the capital of France.",
                    "Berlin is in Germany.",
                ],
                "top_n": 2,
            },
        )
    elapsed = time.perf_counter() - started
    assert resp.status_code == 200, resp.text
    body = resp.json()
    assert body.get("results"), "rerank results missing"
    assert "relevance_score" in body["results"][0]
    assert elapsed < RERANK_LATENCY_S, f"rerank took {elapsed:.1f}s (ceiling {RERANK_LATENCY_S}s)"
