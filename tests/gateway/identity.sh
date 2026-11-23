#!/usr/bin/env bash
# Checks who can reach the model, from the outside: run as a Reader that does not hold AI.Invoke
# (lab-azure-l0-plan in the workflow).
#
#   AZURE_TENANT_ID=<id> AZURE_SUBSCRIPTION_ID=<id> bash tests/gateway/identity.sh results.json
set -euo pipefail
# shellcheck source=lib.sh
source "$(dirname "$0")/lib.sh"

OUT="${1:?results file}"
SUB="${AZURE_SUBSCRIPTION_ID:?set AZURE_SUBSCRIPTION_ID}"
RG="/subscriptions/$SUB/resourceGroups/$PREFIX-rg-aiservices-prd-ae"
ACCOUNT="$RG/providers/Microsoft.CognitiveServices/accounts/$FOUNDRY_NAME"
APIM="$RG/providers/Microsoft.ApiManagement/service/$APIM_NAME"

# Entra issues gateway tokens only to identities assigned AI.Invoke (app_role_assignment_required).
if out="$(az account get-access-token --resource "$AUDIENCE" -o none 2>&1)"; then
  actual=issued
else
  actual="$(grep -o 'AADSTS[0-9]*' <<<"$out" | head -1 || true)"
fi
record GW-01 C-09 "An identity without AI.Invoke cannot get a gateway token" AADSTS501051 "${actual:-error}"

# Every role that grants data actions on the account, held here or inherited from above.
gateway="$(az resource show --ids "$APIM" --query identity.principalId -o tsv)"
assignments="$(az role assignment list --scope "$ACCOUNT" --include-inherited -o json)"
holders="[]"
for role in $(jq -r '[.[].roleDefinitionId] | unique | .[]' <<<"$assignments"); do
  data="$(az role definition list --name "${role##*/}" --scope "/subscriptions/$SUB" \
    --query "[0].permissions[].dataActions[]" -o json)"
  if jq -e '(. // []) | any(.[]; test("^(\\*|Microsoft\\.CognitiveServices/)"; "i"))' <<<"$data" > /dev/null; then
    holders="$(jq -c --arg r "$role" --argjson a "$assignments" \
      '. + [$a[] | select(.roleDefinitionId == $r) | {principal: .principalId, role: .roleDefinitionName}]' <<<"$holders")"
  fi
done
others="$(jq --arg g "$gateway" '[.[] | select(.principal != $g)] | length' <<<"$holders")"
has="$(jq --arg g "$gateway" 'any(.[]; .principal == $g)' <<<"$holders")"
actual="gateway:$has,others:$others"
if [ "$has" = true ] && [ "$others" = 0 ]; then actual=only-gateway; fi
record GW-02 T-04 "Only the gateway holds a data-plane role on the model" only-gateway "$actual" \
  "$(jq -r '[.[].role] | unique | join(", ")' <<<"$holders")"

settings="$(az resource show --ids "$ACCOUNT" \
  --query "properties.{local: disableLocalAuth, public: publicNetworkAccess}" -o json)"
record GW-03 T-05 "The model account refuses API keys" keys-off \
  "$(jq -r 'if .local == true then "keys-off" else "keys-on" end' <<<"$settings")"
record GW-04 T-06 "The model account refuses public traffic" Disabled "$(jq -r .public <<<"$settings")"

finish "$OUT"
