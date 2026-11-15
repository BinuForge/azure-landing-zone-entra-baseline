#!/usr/bin/env bash
# Proves the level 1 policies refuse what they should, and that the study waiver allows only what it
# should. Each case asks Azure Policy which restrictions it would place on a proposed resource
# (checkPolicyRestrictions): the real policy engine evaluates it, nothing is created, and Reader is enough.
#
#   AZURE_SUBSCRIPTION_ID=<id> bash tests/policy/run.sh [results.json]
#
# Exits non-zero if any case does not behave as expected. A denial counts only if the expected lab
# assignment is among those refusing; Microsoft's own system policies may refuse as well.
set -euo pipefail

DIR="$(cd "$(dirname "$0")" && pwd)"
SUB="${AZURE_SUBSCRIPTION_ID:?set AZURE_SUBSCRIPTION_ID}"
OUT="${1:-}"
results="[]"

while read -r case; do
  id="$(jq -r .id <<<"$case")"
  rg="$(jq -r .resource_group <<<"$case")"
  expect="$(jq -r .expect <<<"$case")"
  by="$(jq -r '.by // ""' <<<"$case")"
  body="$(jq -c '{resourceDetails: {resourceContent: .resource, apiVersion: .api_version}, includeAuditEffect: false}' <<<"$case")"

  if out="$(az rest --method post \
      --url "https://management.azure.com/subscriptions/$SUB/resourceGroups/$rg/providers/Microsoft.PolicyInsights/checkPolicyRestrictions?api-version=2024-10-01" \
      --body "$body" -o json 2>&1)"; then
    refused_by="$(jq -c '[.contentEvaluationResult.policyEvaluations[]? | select(.evaluationResult == "NonCompliant")
      | .policyInfo.policyAssignmentId | split("/") | last] | unique' <<<"$out")"
    actual="$(jq -r 'if length == 0 then "allowed" else "denied" end' <<<"$refused_by")"
    detail=""
  else
    refused_by="[]"
    actual="error"
    detail="$(head -c 300 <<<"$out")"
  fi

  pass=false
  if [ "$actual" = "$expect" ] && { [ -z "$by" ] || jq -e --arg b "$by" 'index($b) != null' <<<"$refused_by" > /dev/null; }; then
    pass=true
  fi

  results="$(jq -c --argjson c "$case" --arg a "$actual" --argjson r "$refused_by" --argjson p "$pass" --arg d "$detail" \
    '. + [($c | del(.resource) + {resource_type: .resource.type, location: .resource.location}) + {actual: $a, refused_by: $r, pass: $p} + (if $d == "" then {} else {error: $d} end)]' <<<"$results")"
  printf '%-5s %-5s %s\n' "$id" "$($pass && echo pass || echo FAIL)" "$(jq -r .test <<<"$case")"
done < <(jq -c '.[]' "$DIR/cases.json")

report="$(jq '{method: "Microsoft.PolicyInsights/checkPolicyRestrictions", cases: ., passed: (map(select(.pass)) | length), total: length}' <<<"$results")"
[ -n "$OUT" ] && echo "$report" > "$OUT"
jq -e '.passed == .total' <<<"$report" > /dev/null
