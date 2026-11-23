#!/usr/bin/env bash
# What the ops agent's runner cannot do, tried as the runner (threat model T-02, T-10). Every attempt is
# one that would do no harm if it worked: a tag on the canary, a support name check, a list of reports,
# a `print 1` query.
#
#   AZURE_TENANT_ID=<id> AZURE_SUBSCRIPTION_ID=<id> bash tests/agent/access.sh results.json
set -euo pipefail
# shellcheck source=tests/gateway/lib.sh
source "$(dirname "$0")/../gateway/lib.sh"

OUT="${1:?results file}"
SUB="${AZURE_SUBSCRIPTION_ID:?set AZURE_SUBSCRIPTION_ID}"
CANARY="/subscriptions/$SUB/resourceGroups/$PREFIX-rg-opsagent-np-ae/providers/Microsoft.Network/networkSecurityGroups/$PREFIX-nsg-canary-np-ae"
WORKSPACES="/subscriptions/$SUB/resourceGroups"
OPS="$WORKSPACES/$PREFIX-rg-management-prd-ae/providers/Microsoft.OperationalInsights/workspaces/$PREFIX-log-management-prd-ae"
PROMPTS="$WORKSPACES/$PREFIX-rg-aiservices-prd-ae/providers/Microsoft.OperationalInsights/workspaces/$PREFIX-log-prompts-prd-ae"

token() {
  local t
  t="$(az account get-access-token --resource "$1" --query accessToken -o tsv)"
  if [ -n "${GITHUB_ACTIONS:-}" ]; then echo "::add-mask::$t" >&2; fi
  echo "$t"
}
error_code() { jq -r '.error.code // .error.innererror.code // empty' "$BODY" 2>/dev/null || true; }

arm="$(token https://management.azure.com)"
logs="$(token https://api.loganalytics.io)"
storage="$(token https://storage.azure.com)"

code="$(http "https://management.azure.com$CANARY/providers/Microsoft.Resources/tags/default?api-version=2021-04-01" \
  -X PATCH -H "Authorization: Bearer $arm" -H "Content-Type: application/json" \
  -d '{"operation":"Merge","properties":{"tags":{"t-02":"write-attempt"}}}')"
record T-02b C-03 "The runner cannot change a resource" 403 "$code" "$(error_code)"

# Cost Management Reader and Log Analytics Reader both hold Microsoft.Support/*; the runner's twins do not.
code="$(http "https://management.azure.com/subscriptions/$SUB/providers/Microsoft.Support/checkNameAvailability?api-version=2024-04-01" \
  -X POST -H "Authorization: Bearer $arm" -H "Content-Type: application/json" \
  -d '{"name":"t-02","type":"Microsoft.Support/supportTickets"}')"
record T-02c C-06 "The runner cannot use support requests" 403 "$code" "$(error_code)"

code="$(http "https://$REPORTS_ACCOUNT.blob.core.windows.net/reports?restype=container&comp=list" \
  -H "Authorization: Bearer $storage" -H "x-ms-version: 2023-11-03")"
record T-02d C-12 "The runner can write reports but cannot read them" 403 "$code"

query() {
  http "https://api.loganalytics.io/v1$1/query" -X POST -H "Authorization: Bearer $logs" \
    -H "Content-Type: application/json" -d '{"query":"print 1"}'
}
record T-10a "C-15, C-16" "The runner cannot query the prompt workspace" 403 "$(query "$PROMPTS")" "$(error_code)"
# The same call on the ops workspace succeeds, so the 403 above is the role, not the request.
record T-10b C-06 "The runner can query the ops workspace" 200 "$(query "$OPS")"

finish "$OUT"
