#!/usr/bin/env bash
# Finds anything in the lab subscription that a teardown should have removed, or that bills without
# being in code. Fails if it finds any. Runs in destroy.yml after every teardown, and locally:
#
#   AZURE_SUBSCRIPTION_ID=<id> bash .github/scripts/leftovers.sh [output.json]
#
# Needs a signed-in `az` with Reader on the subscription. Prints types and names, never IDs.
set -euo pipefail

SUB="${AZURE_SUBSCRIPTION_ID:?set AZURE_SUBSCRIPTION_ID}"
OUT="${1:-}"
PREFIX="${PREFIX:-lab}"

# Created by bootstrap and kept between teardowns, so never a leftover.
KEEP_GROUP="${PREFIX}-rg-bootstrap-prd-ae"

# Azure creates these on its own and they do not bill.
EXPECTED_TYPES="'microsoft.network/networkwatchers'"

# Reported as Standard but free: month-to-date cost for the subscription was zero on 2026-11-15 with
# both on. Any other plan above Free bills, and is a leftover.
FREE_DEFENDER_PLANS="Discovery FoundationalCspm"

resources="$(az rest --method post \
  --url "https://management.azure.com/providers/Microsoft.ResourceGraph/resources?api-version=2022-10-01" \
  --body "{\"subscriptions\":[\"$SUB\"],\"query\":\"resources | where resourceGroup !~ '$KEEP_GROUP' and type !in~ ($EXPECTED_TYPES) | project type, resourceGroup, name | order by type asc\"}" \
  --query data -o json)"

defender="$(az rest --method get \
  --url "https://management.azure.com/subscriptions/$SUB/providers/Microsoft.Security/pricings?api-version=2024-01-01" \
  --query "value[?properties.pricingTier!='Free'].name" -o json)"
for plan in $FREE_DEFENDER_PLANS; do
  defender="$(echo "$defender" | jq -c --arg p "$plan" 'map(select(. != $p))')"
done

# A deleted Foundry account is soft-deleted, keeps its name reserved and must be purged.
deleted_ai="$(az rest --method get \
  --url "https://management.azure.com/subscriptions/$SUB/providers/Microsoft.CognitiveServices/deletedAccounts?api-version=2024-10-01" \
  --query "value[].{name:name, location:location}" -o json)"

report="$(jq -n --argjson r "$resources" --argjson d "$defender" --argjson a "$deleted_ai" \
  '{resources: $r, billable_defender_plans: $d, soft_deleted_ai_accounts: $a,
    clean: (($r | length) == 0 and ($d | length) == 0 and ($a | length) == 0)}')"

[ -n "$OUT" ] && echo "$report" > "$OUT"

summary="$(echo "$report" | jq -r '
  "### Leftovers check\n",
  (if .clean then "Clean: nothing outside bootstrap, no billable Defender plans, no soft-deleted AI accounts."
   else
     "| Kind | Type or plan | Resource group | Name |\n|---|---|---|---|",
     (.resources[] | "| Resource | `\(.type)` | `\(.resourceGroup)` | `\(.name)` |"),
     (.billable_defender_plans[] | "| Defender plan | `\(.)` | | |"),
     (.soft_deleted_ai_accounts[] | "| Soft-deleted AI account | | | `\(.name)` (\(.location)) |")
   end)')"

echo "$summary"
[ -n "${GITHUB_STEP_SUMMARY:-}" ] && echo "$summary" >> "$GITHUB_STEP_SUMMARY"

echo "$report" | jq -e '.clean' > /dev/null
