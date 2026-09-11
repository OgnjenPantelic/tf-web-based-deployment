#!/usr/bin/env bash
#
# One-time bootstrap, run from the "Bootstrap (one-time)" GitHub Actions workflow.
# Idempotent: safe to re-run. Creates the GitHub-OIDC identity + Terraform remote
# state storage that the deploy/destroy workflows depend on.
#
# Auth: relies on an already-logged-in `az` session (azure/login in the workflow,
# using a temporary privileged service principal). Subscription and tenant are read
# from that session — nothing extra to pass.
#
# Required inputs (env):
#   STATE_STORAGE_ACCOUNT  globally-unique storage account name (3-24 lowercase alnum)
#   GITHUB_OWNER           repo owner (from github.repository_owner)
#   GITHUB_REPO            repo name  (from github.event.repository.name)
# Optional:
#   LOCATION               Azure region        (default: westeurope)
#   STATE_RG               state resource group (default: tfstate-rg)
#   STATE_CONTAINER        state container      (default: tfstate)
#   IDENTITY_NAME          AD app display name  (default: tf-web-based-deployment-ci)
#   ENVIRONMENTS           space-separated GitHub environments to trust
#                          (default: "azure-prod azure-prod-destroy")

set -euo pipefail

: "${STATE_STORAGE_ACCOUNT:?must set STATE_STORAGE_ACCOUNT}"
: "${GITHUB_OWNER:?must set GITHUB_OWNER}"
: "${GITHUB_REPO:?must set GITHUB_REPO}"
LOCATION="${LOCATION:-westeurope}"
STATE_RG="${STATE_RG:-tfstate-rg}"
STATE_CONTAINER="${STATE_CONTAINER:-tfstate}"
IDENTITY_NAME="${IDENTITY_NAME:-tf-web-based-deployment-ci}"
read -r -a ENVS <<<"${ENVIRONMENTS:-azure-prod azure-prod-destroy}"

# Some subscriptions enforce an "owner" tag on all resources via Azure Policy.
# Default it to the signed-in identity's name; override with OWNER_TAG if needed.
OWNER_TAG="${OWNER_TAG:-$(az account show --query user.name -o tsv)}"

ISSUER="https://token.actions.githubusercontent.com"
AUDIENCE="api://AzureADTokenExchange"

SUBSCRIPTION_ID="$(az account show --query id -o tsv)"
TENANT_ID="$(az account show --query tenantId -o tsv)"
echo "Bootstrapping in subscription ${SUBSCRIPTION_ID} (tenant ${TENANT_ID})"

# 1. State resource group -----------------------------------------------------
az group create -n "$STATE_RG" -l "$LOCATION" --tags "owner=$OWNER_TAG" -o none
echo "✓ resource group: $STATE_RG"

# 2. State storage account (create only if missing) ---------------------------
if ! az storage account show -n "$STATE_STORAGE_ACCOUNT" -g "$STATE_RG" -o none 2>/dev/null; then
  az storage account create -n "$STATE_STORAGE_ACCOUNT" -g "$STATE_RG" -l "$LOCATION" \
    --sku Standard_LRS --kind StorageV2 \
    --min-tls-version TLS1_2 --allow-blob-public-access false \
    --tags "owner=$OWNER_TAG" -o none
fi
az storage account blob-service-properties update \
  --account-name "$STATE_STORAGE_ACCOUNT" --enable-versioning true -o none
echo "✓ storage account: $STATE_STORAGE_ACCOUNT"

# 3. State container ----------------------------------------------------------
# Use key auth: the running identity has management-plane Contributor but not
# necessarily blob data-plane rights, and key auth works for either a user or SP.
ACCOUNT_KEY="$(az storage account keys list -n "$STATE_STORAGE_ACCOUNT" -g "$STATE_RG" --query "[0].value" -o tsv)"
az storage container create -n "$STATE_CONTAINER" \
  --account-name "$STATE_STORAGE_ACCOUNT" --auth-mode key --account-key "$ACCOUNT_KEY" -o none
echo "✓ container: $STATE_CONTAINER"

# 4. AD application + service principal (idempotent by display name) -----------
APP_ID="$(az ad app list --display-name "$IDENTITY_NAME" --query "[0].appId" -o tsv)"
if [ -z "$APP_ID" ]; then
  APP_ID="$(az ad app create --display-name "$IDENTITY_NAME" --query appId -o tsv)"
  echo "✓ created AD application: $APP_ID"
else
  echo "✓ AD application exists: $APP_ID"
fi

SP_OBJECT_ID="$(az ad sp show --id "$APP_ID" --query id -o tsv 2>/dev/null || true)"
if [ -z "$SP_OBJECT_ID" ]; then
  SP_OBJECT_ID="$(az ad sp create --id "$APP_ID" --query id -o tsv)"
fi
echo "✓ service principal object id: $SP_OBJECT_ID"

# 5. Federated credentials, one per GitHub environment ------------------------
# GitHub OIDC subjects on this account embed numeric IDs (owner@<id>/repo@<id>),
# which survive renames. Derive them via gh when available; override with
# GITHUB_OWNER_ID / GITHUB_REPO_ID. Falls back to plain owner/repo if unknown.
OWNER_ID="${GITHUB_OWNER_ID:-}"
REPO_ID="${GITHUB_REPO_ID:-}"
if command -v gh >/dev/null 2>&1; then
  [ -z "$OWNER_ID" ] && OWNER_ID="$(gh api "users/${GITHUB_OWNER}" --jq .id 2>/dev/null || true)"
  [ -z "$REPO_ID" ] && REPO_ID="$(gh api "repos/${GITHUB_OWNER}/${GITHUB_REPO}" --jq .id 2>/dev/null || true)"
fi
if [ -n "$OWNER_ID" ] && [ -n "$REPO_ID" ]; then
  REPO_CLAIM="${GITHUB_OWNER}@${OWNER_ID}/${GITHUB_REPO}@${REPO_ID}"
else
  REPO_CLAIM="${GITHUB_OWNER}/${GITHUB_REPO}"
fi
echo "Using OIDC repo claim: ${REPO_CLAIM}"

for ENVN in "${ENVS[@]}"; do
  SUBJECT="repo:${REPO_CLAIM}:environment:${ENVN}"
  EXISTING="$(az ad app federated-credential list --id "$APP_ID" \
    --query "[?subject=='${SUBJECT}'] | [0].name" -o tsv 2>/dev/null || true)"
  if [ -z "$EXISTING" ]; then
    az ad app federated-credential create --id "$APP_ID" --parameters "$(cat <<JSON
{"name":"github-${ENVN}","issuer":"${ISSUER}","subject":"${SUBJECT}","audiences":["${AUDIENCE}"]}
JSON
)" -o none
    echo "✓ federated credential for environment: $ENVN"
  else
    echo "✓ federated credential exists for environment: $ENVN"
  fi
done

# 6. Role assignments (az role assignment create is idempotent) ---------------
az role assignment create --assignee-object-id "$SP_OBJECT_ID" \
  --assignee-principal-type ServicePrincipal \
  --role "Contributor" --scope "/subscriptions/${SUBSCRIPTION_ID}" -o none
echo "✓ Contributor on subscription"

STORAGE_ID="$(az storage account show -n "$STATE_STORAGE_ACCOUNT" -g "$STATE_RG" --query id -o tsv)"
az role assignment create --assignee-object-id "$SP_OBJECT_ID" \
  --assignee-principal-type ServicePrincipal \
  --role "Storage Blob Data Contributor" --scope "$STORAGE_ID" -o none
echo "✓ Storage Blob Data Contributor on state account"

# 7. Emit values for the GitHub Actions *variables* the deploy workflow needs --
emit() {
  echo "$1"
  [ -n "${GITHUB_STEP_SUMMARY:-}" ] && echo "$1" >>"$GITHUB_STEP_SUMMARY" || true
}
[ -n "${GITHUB_STEP_SUMMARY:-}" ] && {
  echo "## Bootstrap complete — set these as GitHub Actions *variables*" >>"$GITHUB_STEP_SUMMARY"
  echo '```' >>"$GITHUB_STEP_SUMMARY"
}
echo
echo "=============================================================="
echo " Set these as repo GitHub Actions VARIABLES (not secrets):"
echo "=============================================================="
emit "ARM_CLIENT_ID=${APP_ID}"
emit "ARM_TENANT_ID=${TENANT_ID}"
emit "ARM_SUBSCRIPTION_ID=${SUBSCRIPTION_ID}"
emit "TFSTATE_RG=${STATE_RG}"
emit "TFSTATE_SA=${STATE_STORAGE_ACCOUNT}"
emit "TFSTATE_CONTAINER=${STATE_CONTAINER}"
[ -n "${GITHUB_STEP_SUMMARY:-}" ] && echo '```' >>"$GITHUB_STEP_SUMMARY"
echo "=============================================================="
echo "SP object id (for later Databricks account-admin grant): ${SP_OBJECT_ID}"
