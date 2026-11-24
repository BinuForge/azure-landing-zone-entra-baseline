#!/usr/bin/env bash
# Deletes the three workspaces that hold the person-run roots' own state, after a final teardown
# (docs/runbooks/rebuild-in-new-tenant.md). Terraform cannot delete the workspace its own state lives in,
# so these are not in tfc/. Run tfc/'s destroy first. Needs `terraform login`.
#
# Usage: bash tfc/scripts/delete-root-workspaces.sh <organisation> [prefix]
set -euo pipefail

ORG="${1:?usage: delete-root-workspaces.sh <organisation> [prefix]}"
PREFIX="${2:-lab}"
WORKSPACES=("$PREFIX-tfc-l0-bootstrap-prd" "$PREFIX-entra-l0-bootstrap-prd" "$PREFIX-tfc-l0-core-prd")

TOKEN="${TF_TOKEN_app_terraform_io:-$(python3 -c "import json, os; print(json.load(open(os.path.expanduser('~/.terraform.d/credentials.tfrc.json')))['credentials']['app.terraform.io']['token'])")}"
API="https://app.terraform.io/api/v2/organizations/$ORG/workspaces"

echo "This permanently deletes these workspaces and their state in $ORG:"
printf '  %s\n' "${WORKSPACES[@]}"
read -r -p "Type the organisation name to confirm: " answer
[ "$answer" = "$ORG" ] || { echo "Not confirmed. Nothing deleted."; exit 1; }

for ws in "${WORKSPACES[@]}"; do
  code="$(curl -s -o /dev/null -w '%{http_code}' -X DELETE -H "Authorization: Bearer $TOKEN" "$API/$ws")"
  case "$code" in
    204) echo "deleted $ws" ;;
    404) echo "already gone: $ws" ;;
    *) echo "FAILED ($code): $ws" >&2; exit 1 ;;
  esac
done
