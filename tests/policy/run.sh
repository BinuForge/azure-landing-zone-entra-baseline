#!/usr/bin/env bash
# Proves the level 1 policies refuse what they should, and that the study waiver allows what it should.
# Each case asks Azure to validate a deployment: the real policy engine runs, and nothing is created.
#
#   bash tests/policy/run.sh [results.json]
#
# Needs a signed-in `az` allowed to validate deployments (lab-role-deployment-validator, or Owner).
# Exits non-zero if any case does not behave as expected.
set -euo pipefail

DIR="$(cd "$(dirname "$0")" && pwd)"
OUT="${1:-}"
results="[]"

while read -r case; do
  id="$(jq -r .id <<<"$case")"
  scope="$(jq -r .scope <<<"$case")"
  template="$DIR/$(jq -r .template <<<"$case")"
  expect="$(jq -r .expect <<<"$case")"
  by="$(jq -r '.by // ""' <<<"$case")"

  if [ "$scope" = "subscription" ]; then
    out="$(az deployment sub validate --location australiaeast --name "policytest-$id" --template-file "$template" -o json 2>&1 || true)"
  else
    out="$(az deployment group validate -g "$scope" --name "policytest-$id" --template-file "$template" -o json 2>&1 || true)"
  fi

  if grep -q 'RequestDisallowedByPolicy' <<<"$out"; then
    actual="denied"
  elif grep -qE '"provisioningState": *"Succeeded"' <<<"$out"; then
    actual="allowed"
  else
    actual="error"
  fi
  denied_by="$(grep -oE 'lab-(baseline|ai-account|ai-deployments|corp-no-pip|mcsb)' <<<"$out" | sort -u | paste -sd, - || true)"

  pass=false
  if [ "$actual" = "$expect" ] && { [ -z "$by" ] || [[ ",$denied_by," == *",$by,"* ]]; }; then
    pass=true
  fi
  detail=""
  [ "$actual" = "error" ] && detail="$(grep -oE '"message": *"[^"]{0,200}' <<<"$out" | head -1 | sed 's/"message": *"//')"

  results="$(jq -c --argjson c "$case" --arg a "$actual" --arg b "$denied_by" --argjson p "$pass" --arg d "$detail" \
    '. + [$c + {actual: $a, denied_by: $b, pass: $p} + (if $d == "" then {} else {error: $d} end)]' <<<"$results")"
  printf '%-5s %-8s %s\n' "$id" "$($pass && echo pass || echo FAIL)" "$(jq -r .test <<<"$case")"
done < <(jq -c '.[]' "$DIR/cases.json")

report="$(jq '{cases: ., passed: (map(select(.pass)) | length), total: length}' <<<"$results")"
[ -n "$OUT" ] && echo "$report" > "$OUT"
jq -e '.passed == .total' <<<"$report" > /dev/null
