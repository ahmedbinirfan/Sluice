.PHONY: up down tf-apply tf-destroy kubeconfig argo-install argo-root smoke eval gate loadtest redteam lint test help

TF := terraform -chdir=infra/terraform
RG := rg-sluice-dev-aue
AKS := aks-sluice-dev-aue

help:
	@echo "up down smoke eval gate loadtest redteam lint test"
	@echo "up   — terraform apply + kubeconfig + Argo CD + root app-of-apps"
	@echo "down — terraform destroy (tears down AKS and the rest of the stack)"

# SLU-50: rebuild the Phase 1 cluster and GitOps control plane.
up: tf-apply kubeconfig argo-install argo-root
	@echo "Sluice is up. Argo syncs deploy/argocd/ from Git (main)."

tf-apply:
	$(TF) init -input=false
	$(TF) apply -input=false -auto-approve

kubeconfig:
	az aks get-credentials -g $(RG) -n $(AKS) --overwrite-existing

argo-install:
	helm repo add argo https://argoproj.github.io/argo-helm
	helm repo update argo
	helm upgrade --install argocd argo/argo-cd \
		--namespace argocd --create-namespace \
		--version 10.11.6 \
		-f deploy/bootstrap/argo-cd-values.yaml \
		--wait --timeout 15m

argo-root:
	# Apply apps from this checkout first so `make up` works before the PR lands on main.
	# The root Application then keeps deploy/argocd/ synced from Git.
	kubectl apply -f deploy/argocd/
	kubectl apply -f deploy/bootstrap/root-application.yaml
	@echo "Waiting for Applications..."
	kubectl -n argocd wait --for=jsonpath='{.status.health.status}'=Healthy application/root --timeout=5m || true
	kubectl -n argocd get applications

# SLU-50: tear down cloud resources. Habit: run at end of every session.
down: tf-destroy

tf-destroy:
	$(TF) init -input=false
	$(TF) destroy -input=false -auto-approve

# SLU-57: chat + embed + rerank through the LiteLLM gateway.
smoke:
	./scripts/sync-litellm-secrets.sh
	./scripts/with-gateway.sh uv run pytest tests/test_smoke.py -q

# SLU-56: deepen vllm:num_requests_waiting; watch `kubectl -n sluice get sts,pods,hpa,scaledobject -w`.
# For a stronger KEDA signal, port-forward sluice-vllm and run burst_queue.py --direct-vllm.
loadtest:
	./scripts/with-gateway.sh uv run python loadtest/burst_queue.py --concurrency 32 --waves 2 --max-tokens 256

eval gate redteam:
	@echo TODO

lint:
	uv run ruff check .
	uv run ruff format --check .

test:
	uv run pytest
