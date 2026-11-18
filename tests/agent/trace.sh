#!/usr/bin/env bash
# Follows this run's ID from GitHub through the gateway to Foundry (threat model T-13), after live.py has
# made its model calls. Run as the runner, which can query the ops workspace and nothing else.
#
#   The gateway log holds the run ID (x-correlation-id) and the request ID APIM sent on to Foundry
#   (x-ms-client-request-id). Foundry's log should hold that request ID as its CorrelationId.
#
# Logs take minutes to arrive, so it asks every minute for up to 15.
#
#   AZURE_TENANT_ID=<id> AZURE_SUBSCRIPTION_ID=<id> GITHUB_RUN_ID=<id> bash tests/agent/trace.sh results.json
set -euo pipefail
# shellcheck source=tests/gateway/lib.sh
source "$(dirname "$0")/../gateway/lib.sh"

OUT="${1:?results file}"
SUB="${AZURE_SUBSCRIPTION_ID:?set AZURE_SUBSCRIPTION_ID}"
RUN="${GITHUB_RUN_ID:?set GITHUB_RUN_ID}"
OPS="/subscriptions/$SUB/resourceGroups/$PREFIX-rg-management-prd-ae/providers/Microsoft.OperationalInsights/workspaces/$PREFIX-log-management-prd-ae"

logs="$(az account get-access-token --resource https://api.loganalytics.io --query accessToken -o tsv)"
if [ -n "${GITHUB_ACTIONS:-}" ]; then echo "::add-mask::$logs"; fi

KQL="$(cat <<EOF
let gateway = AzureDiagnostics
| where TimeGenerated > ago(3h) and ResourceProvider == "MICROSOFT.APIMANAGEMENT"
| where column_ifexists("requestHeaders_x_correlation_id_s", "") == "$RUN";
let sent = gateway
| extend id = tolower(column_ifexists("backendRequestHeaders_x_ms_client_request_id_s", ""))
| where isnotempty(id)
| distinct id;
let foundry = AzureDiagnostics
| where TimeGenerated > ago(3h) and ResourceProvider == "MICROSOFT.COGNITIVESERVICES"
| where tolower(CorrelationId) in (sent);
print gateway = toscalar(gateway | count), sent = toscalar(sent | count), foundry = toscalar(foundry | count)
EOF
)"

counts='{"gateway":0,"sent":0,"foundry":0}'
start=$SECONDS
while :; do
  code="$(http "https://api.loganalytics.io/v1$OPS/query" -X POST -H "Authorization: Bearer $logs" \
    -H "Content-Type: application/json" -d "$(jq -n --arg q "$KQL" '{query: $q}')")"
  if [ "$code" = 200 ]; then
    counts="$(jq -c '.tables[0] as $t | [$t.columns[].name] as $n | $t.rows[0] as $r
      | [range(0; $n | length) | {key: $n[.], value: $r[.]}] | from_entries' "$BODY")"
  fi
  if jq -e '.gateway > 0 and .foundry > 0' <<<"$counts" > /dev/null || (( SECONDS - start >= 900 )); then break; fi
  sleep 60
done
waited="$(( (SECONDS - start) / 60 )) min"
found() { jq -r --arg k "$1" 'if .[$k] > 0 then "found" else "missing" end' <<<"$counts"; }

record T-13a C-22 "The gateway log holds this run's ID" found "$(found gateway)" "$(jq -r .gateway <<<"$counts") records, after $waited"
record T-13b C-22 "The gateway log holds the request ID it sent to Foundry" found "$(found sent)" "$(jq -r .sent <<<"$counts") IDs"
record T-13c C-22 "Foundry's log holds those request IDs" found "$(found foundry)" "$(jq -r .foundry <<<"$counts") records"

finish "$OUT"
