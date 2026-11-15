#!/usr/bin/env bash
# Collects an evidence pack from live Azure into a folder (ADR-0011). Every file is redacted and scanned
# by redact-evidence.py before it is attested; this script never writes anything else.
#
#   AZURE_SUBSCRIPTION_ID=<id> bash .github/scripts/collect-evidence.sh <label> <out-dir>
#
# Needs a signed-in `az` with Reader at the root management group.
set -euo pipefail

LABEL="${1:?label, for example 2026-11-19-aiservices}"
OUT="${2:?output directory}"
SUB="${AZURE_SUBSCRIPTION_ID:?set AZURE_SUBSCRIPTION_ID}"
PREFIX="${PREFIX:-lab}"
mkdir -p "$OUT"

graph() {
  az rest --method post \
    --url "https://management.azure.com/providers/Microsoft.ResourceGraph/resources?api-version=2022-10-01" \
    --body "{\"subscriptions\":[\"$SUB\"],\"query\":\"$1\"}" --query data -o json
}

# Where things sit: the management group tree and the subscription's place in it.
# --no-register: without it the CLI tries to register Microsoft.Management on every call, a write action
# this read-only identity is rightly refused. Bootstrap registers providers.
az account management-group show --name "${PREFIX}-mg-root" --expand --recurse --no-register -o json \
  | jq 'def walk_mg: {name, displayName, type: (.type | split("/") | last),
          children: [(.children // [])[] | walk_mg]}; walk_mg' > "$OUT/management-groups.json"

tenant="$(az account show --query tenantId -o tsv)"
az rest --method get \
  --url "https://management.azure.com/providers/Microsoft.Management/managementGroups/$tenant/settings/default?api-version=2023-04-01" \
  --query "properties.{defaultManagementGroup:defaultManagementGroup, requireAuthorizationForGroupCreation:requireAuthorizationForGroupCreation}" \
  -o json > "$OUT/hierarchy-settings.json"

# Who can do what: pipeline and maintainer role assignments made by bootstrap, by role and scope only.
az role assignment list --all --fill-principal-name false \
  --query "[?starts_with(description || '', 'Bootstrap')].{role:roleDefinitionName, scope:scope, principalType:principalType, conditional:condition != null}" \
  -o json | jq 'sort_by(.role, .scope)' > "$OUT/role-assignments.json"

# What exists: every resource in the subscription, by type, group and name.
graph "resources | project type, resourceGroup, name, location | order by type asc" > "$OUT/resources.json"

# What it costs: month to date, by service.
az rest --method post \
  --url "https://management.azure.com/subscriptions/$SUB/providers/Microsoft.CostManagement/query?api-version=2023-11-01" \
  --body '{"type":"ActualCost","timeframe":"MonthToDate","dataset":{"granularity":"None","aggregation":{"cost":{"name":"Cost","function":"Sum"}},"grouping":[{"type":"Dimension","name":"ServiceName"}]}}' \
  --query "properties.{columns:columns[].name, rows:rows}" -o json > "$OUT/cost-month-to-date.json"

# Anything that should not be there.
bash "$(dirname "$0")/leftovers.sh" "$OUT/leftovers.json" > /dev/null || true

jq -n --arg label "$LABEL" --arg run "${GITHUB_RUN_ID:-local}" --arg sha "${GITHUB_SHA:-$(git rev-parse HEAD)}" \
  --arg at "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
  '{label: $label, collected_at: $at, workflow_run: $run, commit: $sha,
    files: ["management-groups.json", "hierarchy-settings.json", "role-assignments.json", "resources.json", "cost-month-to-date.json", "leftovers.json"]}' \
  > "$OUT/manifest.json"

echo "Collected $(ls "$OUT" | wc -l | tr -d ' ') files into $OUT"
