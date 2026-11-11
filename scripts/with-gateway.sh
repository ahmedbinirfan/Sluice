#!/usr/bin/env bash
# Port-forward sluice-litellm, export SLUICE_* for smoke/loadtest, run the given command.
set -euo pipefail

NS="${NS:-sluice}"
LOCAL_PORT="${LOCAL_PORT:-4000}"
VAULT="${VAULT:-kv-sluice-dev-aue}"

need() { command -v "$1" >/dev/null || { echo "missing $1" >&2; exit 1; }; }
need kubectl
need az

pkill -f "port-forward.*sluice-litellm" 2>/dev/null || true
kubectl -n "$NS" port-forward svc/sluice-litellm "${LOCAL_PORT}:4000" >/tmp/sluice-gateway-pf.log 2>&1 &
PF_PID=$!
cleanup() { kill "$PF_PID" 2>/dev/null || true; }
trap cleanup EXIT

for _ in $(seq 1 30); do
  if curl -sf "http://127.0.0.1:${LOCAL_PORT}/health/liveliness" >/dev/null 2>&1 \
    || curl -sf "http://127.0.0.1:${LOCAL_PORT}/health/readiness" >/dev/null 2>&1; then
    break
  fi
  sleep 1
done

export SLUICE_GATEWAY_URL="http://127.0.0.1:${LOCAL_PORT}"
export SLUICE_MASTER_KEY
SLUICE_MASTER_KEY="$(az keyvault secret show --vault-name "$VAULT" --name litellm-master-key --query value -o tsv)"

exec "$@"
