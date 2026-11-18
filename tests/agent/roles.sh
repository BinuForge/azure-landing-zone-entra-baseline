#!/usr/bin/env bash
# Lists every role the ops agent's runner holds in the subscription and checks each action (threat model
# T-02). Run as a Reader that can see every assignment (lab-azure-l0-plan in the workflow); the runner
# itself cannot list assignments above its resource groups.
#
#   AZURE_TENANT_ID=<id> AZURE_SUBSCRIPTION_ID=<id> RUNNER_OBJECT_ID=<id> bash tests/agent/roles.sh results.json
set -euo pipefail
# shellcheck source=tests/gateway/lib.sh
source "$(dirname "$0")/../gateway/lib.sh"

OUT="${1:?results file}"
SUB="${AZURE_SUBSCRIPTION_ID:?set AZURE_SUBSCRIPTION_ID}"
OID="${RUNNER_OBJECT_ID:?set RUNNER_OBJECT_ID}"

# Reads, the two log query actions, and the report writer's two blob actions: anything else is a write.
READ='/read$|^Microsoft\.OperationalInsights/workspaces/(analytics/query|search)/action$'
DATA='^Microsoft\.Storage/storageAccounts/blobServices/containers/blobs/(write|add/action)$'

# Assignments at, above and below the subscription for this principal.
assignments="$(az rest --method get \
  --url "https://management.azure.com/subscriptions/$SUB/providers/Microsoft.Authorization/roleAssignments?api-version=2022-04-01&\$filter=principalId%20eq%20'$OID'" \
  --query value -o json)"

roles="[]"
for id in $(jq -r '[.[].properties.roleDefinitionId] | unique | .[]' <<<"$assignments"); do
  roles="$(jq -c --argjson d "$(az rest --method get --url "https://management.azure.com$id?api-version=2022-04-01" -o json)" \
    '. + [{name: $d.properties.roleName, actions: [$d.properties.permissions[].actions[]],
           data: [$d.properties.permissions[].dataActions[]]}]' <<<"$roles")"
done

writes="$(jq -c --arg r "$READ" --arg d "$DATA" \
  '[.[] | .name as $n | (.actions[] | select(test($r) | not) | "\($n): \(.)"), (.data[] | select(test($d) | not) | "\($n): \(.)")]' <<<"$roles")"
actual="read-only"
if [ "$(jq length <<<"$writes")" -gt 0 ]; then actual="$(jq length <<<"$writes") write actions"; fi
record T-02a C-06 "Every role the runner holds is read-only, apart from adding reports" read-only "$actual" \
  "$(jq -r 'length' <<<"$assignments") assignments: $(jq -r '[.[].name] | sort | join(", ")' <<<"$roles")$(jq -r 'if length > 0 then "; " + join(", ") else "" end' <<<"$writes")"

finish "$OUT"
