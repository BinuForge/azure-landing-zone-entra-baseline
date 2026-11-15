#!/usr/bin/env bash
# Calls the AI gateway as the ops agent's runner, the only identity holding AI.Invoke (bootstrap/gateway.tf),
# and checks each answer. Ends with the token limit, because that test uses the caller's limit up.
#
#   AZURE_TENANT_ID=<id> bash tests/gateway/caller.sh results.json
set -euo pipefail
# shellcheck source=lib.sh
source "$(dirname "$0")/lib.sh"

OUT="${1:?results file}"
PING='{"messages":[{"role":"user","content":"Reply with one word: pong"}],"max_completion_tokens":200}'
LONG='{"messages":[{"role":"user","content":"Write 600 words on why landing zones matter."}],"max_completion_tokens":1500}'

# chat <deployment> <token or empty> <body>
chat() {
  local auth=()
  if [ -n "$2" ]; then auth=(-H "Authorization: Bearer $2"); fi
  http "$GATEWAY/deployments/$1/chat/completions?$API" -X POST "${auth[@]}" \
    -H "Content-Type: application/json" -H "x-correlation-id: ${GITHUB_RUN_ID:-local}" -d "$3"
}

token() {
  local t
  t="$(az account get-access-token --resource "$1" --query accessToken -o tsv)"
  if [ -n "${GITHUB_ACTIONS:-}" ]; then echo "::add-mask::$t" >&2; fi
  echo "$t"
}

gateway_token="$(token "$AUDIENCE")"
other_token="$(token https://cognitiveservices.azure.com)"

record GW-05 C-09 "A call with no token is refused" 401 "$(chat "$DEPLOYMENT" "" "$PING")"
record GW-06 C-09 "A token for another audience is refused" 401 "$(chat "$DEPLOYMENT" "$other_token" "$PING")"

code="$(chat "$DEPLOYMENT" "$gateway_token" "$PING")"
record GW-07 C-08 "A gateway token with AI.Invoke reaches the model" 200 "$code" \
  "$(jq -r '"model \(.model // "none"), \(.usage.total_tokens // 0) tokens"' "$BODY" 2>/dev/null || true)"

record GW-08 C-24 "A deployment that does not exist is not served" 404 \
  "$(chat gpt-4o "$gateway_token" "$PING")"

# Straight to the model with the runner's own token, skipping the gateway. Foundry checks the caller's
# role before its network rules, so a caller with no role is refused there and the network layer is not
# reached; GW-04 covers that layer by its setting.
code="$(http "$FOUNDRY/deployments/$DEPLOYMENT/chat/completions?$API" -X POST \
  -H "Authorization: Bearer $other_token" -H "Content-Type: application/json" -d "$PING")"
if [ "$code" = 401 ] && grep -q "lacks the required data action" "$BODY"; then code=401-no-role; fi
record GW-09 T-04 "A direct call to the model, skipping the gateway, is refused" "401-no-role|403|no-response" "$code"

limit=none
for i in $(seq 1 40); do
  code="$(chat "$DEPLOYMENT" "$gateway_token" "$LONG")"
  if [ "$code" != 200 ]; then limit="$code"; break; fi
done
record GW-10 T-11 "Calls past the caller's token limit are refused" 429 "$limit" "after $i calls"

finish "$OUT"
