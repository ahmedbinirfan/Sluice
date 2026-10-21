# Sluice

Self-hosted, air-gappable GenAI platform on Kubernetes: vLLM serving, a multi-tenant LLM gateway with token quotas and budgets, guardrails, OpenTelemetry tracing, and an eval-gated canary release pipeline. Azure-first, runs on-prem with egress blocked.

## Architecture

Diagram placeholder. The picture of tenants, the gateway, vLLM, and the eval gate will go here.

## Quickstart

```bash
make up
```

Coming in Phase 1. The target exists and prints `TODO` until the local cluster is built.

## Status

Phase 0: repo scaffold, local toolchain, and commit hooks.

## Docs

- [Local setup](docs/setup.md)
- [Architecture decision records](docs/adr/0001-record-architecture-decisions.md)
