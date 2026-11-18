#!/usr/bin/env bash
# Sets the two pipeline credentials in every Terraform environment, outside Terraform so they never
# reach state (ADR-0012, decision 5). Run again to rotate both. See docs/runbooks/bootstrap.md.
#
#   bash bootstrap/scripts/set-pipeline-secrets.sh
#
# TF_TOKEN_APP_TERRAFORM_IO  HCP Terraform owners team token, pasted at the prompt (ADR-0002).
# PLAN_ENCRYPTION_KEY        Random key per level (per workspace for Entra), shared by its plan and apply
#                            environments.
#
# Written for bash 3.2, which macOS ships, so no associative arrays or mapfile.
set -euo pipefail

REPO="${REPO:-BinuForge/azure-landing-zone-entra-baseline}"
PREFIX="${PREFIX:-lab}"

# Terraform environments only. The ops agent runner never runs Terraform, so it gets neither secret.
ENVIRONMENTS="$(gh api "repos/$REPO/environments" --jq '.environments[].name' \
  | grep -E "^${PREFIX}-[a-z]+-l[0-9]-([a-z]+-)?(plan|apply)$" | sort || true)"

if [ -z "$ENVIRONMENTS" ]; then
  echo "No plan or apply environments found in $REPO. Run the bootstrap apply first." >&2
  exit 1
fi

echo "Environments:"
echo "$ENVIRONMENTS"
read -r -s -p "Paste the HCP Terraform owners team token (input hidden): " TF_TOKEN
echo
if [ -z "$TF_TOKEN" ]; then
  echo "No token entered." >&2
  exit 1
fi

# One key per level (lab-azure-l2) or Entra workspace (lab-entra-l1-ca), shared by its plan and apply
# environments.
LEVELS="$(echo "$ENVIRONMENTS" | sed -E 's/-(plan|apply)$//' | sort -u)"

for level in $LEVELS; do
  key="$(openssl rand -base64 32)"
  for env in $(echo "$ENVIRONMENTS" | grep -E "^${level}-(plan|apply)$"); do
    # Values go through stdin, never the command line, so they do not appear in the process list.
    printf '%s' "$TF_TOKEN" | gh secret set TF_TOKEN_APP_TERRAFORM_IO --repo "$REPO" --env "$env"
    printf '%s' "$key" | gh secret set PLAN_ENCRYPTION_KEY --repo "$REPO" --env "$env"
    echo "Set secrets in $env"
  done
done

unset TF_TOKEN key

echo
echo "Secret names per environment (values are never shown):"
for env in $ENVIRONMENTS; do
  echo "$env: $(gh api "repos/$REPO/environments/$env/secrets" --jq '[.secrets[].name] | join(", ")')"
done
