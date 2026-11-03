# Sluice

Self-hosted, air-gappable GenAI platform on Kubernetes: vLLM serving, a multi-tenant LLM gateway with token quotas and budgets, guardrails, OpenTelemetry tracing, and an eval-gated canary release pipeline. Azure-first, runs on-prem with egress blocked.

## Architecture

Diagram placeholder. The picture of tenants, the gateway, vLLM, and the eval gate will go here.

## Quickstart

```bash
make up    # terraform apply + kubeconfig + Argo CD + root app-of-apps
make down  # terraform destroy — run at end of every paid session
```

Requires Azure CLI login, Terraform, Helm, and kubectl. Argo syncs `deploy/argocd/` from `main`.

## Status

Phase 0 done. Phase 1 (SLU-5): AKS + spot GPU pool + NVIDIA device plugin + Argo CD app-of-apps + umbrella Helm skeleton.

## Docs

- [Local setup](docs/setup.md)
- [Architecture decision records](docs/adr/0001-record-architecture-decisions.md)
- [Azure region and naming](docs/adr/0002-azure-naming-and-region.md)
