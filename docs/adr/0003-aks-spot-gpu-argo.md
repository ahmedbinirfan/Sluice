# ADR 0003: AKS, spot GPU pool, and Argo CD

## Status

Accepted

## Context

Sluice needs a managed Kubernetes control plane in Australia East, a cheap GPU for intermittent vLLM work, and a deploy path that does not depend on whoever last ran Helm on a laptop. The monthly budget is AUD 30. Phase 0 already chose the region, naming, remote state, and OIDC.

## Decision

- **AKS** for the first cloud cluster: Free SKU control plane, Azure CNI Overlay, Calico, OIDC issuer, and workload identity.
- **System pool** on a small CPU SKU (`Standard_D4s_v6`) for platform pods (Argo CD, gateways, observability).
- **Separate user pool** for GPUs: `Standard_NC4as_T4_v3`, Spot + Delete eviction, autoscaling `min_count = 0` / `max_count = 1`, label `pool=gpu`, taint `nvidia.com/gpu=present:NoSchedule`.
- **Argo CD** as GitOps: Helm bootstrap once, then a root Application syncs `deploy/argocd/` (app-of-apps). Day-two deploys are Git commits, not laptop `helm install`.

## Consequences

Idle cost is dominated by the system node; the GPU node only exists when a pod that tolerates Spot + GPU taints requests `nvidia.com/gpu`. Cluster autoscaler scale-up from 0 can take several minutes (measured ~9 minutes for a CUDA `nvidia-smi` test). Spot eviction can kill running vLLM pods; treat GPU work as interruptible and rely on reschedule.

`make up` / `make down` wrap Terraform apply/destroy plus Argo bootstrap so sessions start and stop cleanly. Habit: `make down` at the end of every paid session.

## Alternatives considered

- **k3s/k3d only** — fine for Phase 0 learning; not the Azure portfolio path for AKS + spot GPU + workload identity.
- **On-demand GPU nodes** — simpler scheduling, burns the AUD 30 budget in ~30 hours.
- **GPU Operator instead of device plugin** — heavier; device plugin is enough until driver management becomes a story.
- **Flux instead of Argo CD** — equally valid GitOps; Argo’s Application CRD and UI match the interview narrative for app-of-apps.
- **Laptop Helm as the long-term deploy path** — drifts from Git; rejected after the Argo bootstrap.
