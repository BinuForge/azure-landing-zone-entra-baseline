#!/usr/bin/env bash
# Checks to run before the first deployment of your own copy (QUICKSTART.md). Read-only: it changes
# nothing in Azure, Entra, GitHub or HCP Terraform.
#
# Usage: bash bootstrap/scripts/preflight.sh <unique_suffix> [prefix]
#   unique_suffix  1 to 3 lowercase letters or digits, added to the names that must be unique across
#                  Azure (docs/naming.md). Pick something random, for example "k7q".
#   prefix         Optional, default "lab". Leave it unless you have a reason to change it.
set -uo pipefail

SUFFIX="${1:-}"
PREFIX="${2:-lab}"
REGION_CODE="ae" # australiaeast, the default location (docs/naming.md)
FAILED=0

ok() { printf '  ok    %s\n' "$1"; }
bad() { printf '  FAIL  %s\n' "$1"; FAILED=1; }
warn() { printf '  warn  %s\n' "$1"; }

echo "Inputs"
if [[ "$PREFIX" =~ ^[a-z]{2,5}$ ]]; then ok "prefix $PREFIX"; else bad "prefix must be 2 to 5 lowercase letters"; fi
if [[ "$SUFFIX" =~ ^[a-z0-9]{1,3}$ ]]; then
  ok "unique suffix $SUFFIX"
else
  bad "give a unique suffix of 1 to 3 lowercase letters or digits; only the original lab runs without one"
fi

echo "Tools (docs/runbooks/local-setup.md)"
for tool in terraform az gh python3 jq; do
  if command -v "$tool" >/dev/null 2>&1; then ok "$tool"; else bad "$tool is not installed"; fi
done

echo "Sign-ins"
if az account show >/dev/null 2>&1; then ok "az, as $(az account show --query user.name -o tsv)"; else bad "run az login"; fi
if gh auth status >/dev/null 2>&1; then ok "gh"; else bad "run gh auth login"; fi
if [[ -n "${TF_TOKEN_app_terraform_io:-}" || -f "$HOME/.terraform.d/credentials.tfrc.json" ]]; then
  ok "terraform login"
else
  bad "run terraform login"
fi
[[ "$FAILED" -eq 0 ]] || { echo "Fix the failures above, then run this again."; exit 1; }

SUB="$(az account show --query id -o tsv)"

echo "Subscription"
read -r QUOTA LIMIT STATE < <(az rest --method get \
  --url "https://management.azure.com/subscriptions/$SUB?api-version=2022-12-01" \
  --query "[subscriptionPolicies.quotaId, subscriptionPolicies.spendingLimit, state]" -o tsv | tr '\n' ' ')
if [[ "$STATE" != "Enabled" ]]; then bad "subscription state is $STATE"; else ok "subscription enabled"; fi
if [[ "$QUOTA" == FreeTrial* && "$LIMIT" == "On" ]]; then
  ok "free trial with the spending limit on: it cannot charge a card"
else
  warn "not a free trial with a spending limit ($QUOTA, limit $LIMIT): charges can reach your card, and budgets alert but do not stop spending"
fi

echo "Tenant"
USERS="$(az ad user list --query "length(@)" -o tsv 2>/dev/null || echo "?")"
if [[ "$USERS" =~ ^[0-9]+$ && "$USERS" -le 5 ]]; then
  ok "$USERS users: looks like a new tenant"
else
  warn "$USERS users. The Entra levels change sign-in settings for everyone in the tenant (SMS off, Conditional Access, consent off). Use a new trial tenant, never one people rely on."
fi
P2="$(az rest --method get --url "https://graph.microsoft.com/v1.0/subscribedSkus" \
  --query "length(value[?servicePlans[?servicePlanName=='AAD_PREMIUM_P2']])" -o tsv 2>/dev/null || echo "?")"
if [[ "$P2" =~ ^[1-9] ]]; then ok "Entra ID P2 (or a trial) found"; else warn "no Entra ID P2 found (or it could not be read). Start the P2 trial before the Entra levels: PIM and risk-based Conditional Access need it."; fi

echo "Names that must be unique across Azure"
STORAGE="${PREFIX}streportsprd${REGION_CODE}01${SUFFIX}"
FOUNDRY="${PREFIX}-ais-aiservices-prd-${REGION_CODE}-${SUFFIX}"
APIM="${PREFIX}-apim-aiservices-prd-${REGION_CODE}-${SUFFIX}"

if [[ "$(az storage account check-name --name "$STORAGE" --query nameAvailable -o tsv)" == "true" ]]; then
  ok "storage account $STORAGE"
else
  bad "storage account $STORAGE is taken: pick another suffix"
fi
if [[ "$(az rest --method post \
  --url "https://management.azure.com/subscriptions/$SUB/providers/Microsoft.CognitiveServices/checkDomainAvailability?api-version=2023-05-01" \
  --body "{\"subdomainName\":\"$FOUNDRY\",\"type\":\"Microsoft.CognitiveServices/accounts\",\"kind\":\"AIServices\"}" \
  --query isSubdomainAvailable -o tsv)" == "true" ]]; then
  ok "Foundry subdomain $FOUNDRY"
else
  bad "Foundry subdomain $FOUNDRY is taken: pick another suffix"
fi
if [[ "$(az apim check-name --name "$APIM" --query nameAvailable -o tsv 2>/dev/null)" == "true" ]]; then
  ok "API Management $APIM"
else
  bad "API Management $APIM is taken, or a deleted service still holds it: pick another suffix"
fi
if [[ "$(az rest --method get \
  --url "https://management.azure.com/subscriptions/$SUB/providers/Microsoft.Network/locations/australiaeast/CheckDnsNameAvailability?domainNameLabel=$APIM&api-version=2023-09-01" \
  --query available -o tsv)" == "true" ]]; then
  ok "public IP label $APIM"
else
  bad "public IP label $APIM is taken: pick another suffix"
fi

echo "Repository"
REPO="$(gh repo view --json nameWithOwner --jq .nameWithOwner 2>/dev/null || true)"
if [[ -z "$REPO" ]]; then
  bad "run this from your fork's clone"
else
  ok "$REPO"
  if [[ "$(gh repo view --json visibility --jq .visibility)" == "PUBLIC" ]]; then
    ok "public, so environments can require a reviewer on the free plan"
  else
    warn "private: on the free plan, environment reviewers need a public repository (docs/runbooks/repo-governance.md)"
  fi
  SET="$(gh variable get LAB_UNIQUE_SUFFIX --repo "$REPO" 2>/dev/null || true)"
  if [[ "$SET" == "$SUFFIX" ]]; then
    ok "repository variable LAB_UNIQUE_SUFFIX is $SUFFIX"
  else
    bad "set the repository variable: gh variable set LAB_UNIQUE_SUFFIX --body $SUFFIX --repo $REPO"
  fi
  SUBJECT="$(gh api "repos/$REPO/actions/oidc/customization/sub" --jq '.sub_claim_prefix // empty' 2>/dev/null || true)"
  if [[ -n "$SUBJECT" ]]; then
    ok "OIDC subject prefix for the tfvars: $SUBJECT"
  else
    warn "could not read the OIDC subject prefix; see github_oidc_subject_prefix in bootstrap/variables.tf"
  fi
fi

echo
if [[ "$FAILED" -eq 0 ]]; then
  echo "Ready. Put unique_suffix = \"$SUFFIX\" in bootstrap/env/lab.auto.tfvars, then follow QUICKSTART.md."
else
  echo "Fix the failures above, then run this again."
fi
exit "$FAILED"
