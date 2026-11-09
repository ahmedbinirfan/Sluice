#!/usr/bin/env bash
# SLU-55: put LiteLLM secrets in Key Vault, then mirror into the sluice namespace.
# Master key never lands in Git. Re-run anytime before enabling / after make up.
set -euo pipefail

VAULT="${VAULT:-kv-sluice-dev-aue}"
NS="${NS:-sluice}"
SECRET_NAME="${SECRET_NAME:-sluice-litellm}"
DB_USER="${DB_USER:-litellm}"
DB_NAME="${DB_NAME:-litellm}"
DB_HOST="${DB_HOST:-sluice-litellm-db}"
DB_PORT="${DB_PORT:-5432}"

need() { command -v "$1" >/dev/null || { echo "missing $1" >&2; exit 1; }; }
need az
need kubectl
need python3

ensure_kv_secret() {
  local name="$1"
  local value="$2"
  if az keyvault secret show --vault-name "$VAULT" --name "$name" --query id -o tsv >/dev/null 2>&1; then
    echo "Key Vault secret $name already exists"
  else
    az keyvault secret set --vault-name "$VAULT" --name "$name" --value "$value" >/dev/null
    echo "Created Key Vault secret $name"
  fi
}

MASTER="$(python3 -c 'import secrets; print("sk-" + secrets.token_urlsafe(32))')"
PGPASS="$(python3 -c 'import secrets; print(secrets.token_urlsafe(24))')"

ensure_kv_secret litellm-master-key "$MASTER"
ensure_kv_secret litellm-postgres-password "$PGPASS"

MASTER_KEY="$(az keyvault secret show --vault-name "$VAULT" --name litellm-master-key --query value -o tsv)"
POSTGRES_PASSWORD="$(az keyvault secret show --vault-name "$VAULT" --name litellm-postgres-password --query value -o tsv)"
DATABASE_URL="postgresql://${DB_USER}:${POSTGRES_PASSWORD}@${DB_HOST}:${DB_PORT}/${DB_NAME}"

kubectl get ns "$NS" >/dev/null 2>&1 || kubectl create namespace "$NS"

kubectl -n "$NS" create secret generic "$SECRET_NAME" \
  --from-literal=master-key="$MASTER_KEY" \
  --from-literal=postgres-password="$POSTGRES_PASSWORD" \
  --from-literal=database-url="$DATABASE_URL" \
  --dry-run=client -o yaml | kubectl apply -f -

echo "Synced K8s secret ${NS}/${SECRET_NAME} from Key Vault ${VAULT}"
