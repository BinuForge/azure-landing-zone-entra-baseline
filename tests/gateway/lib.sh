# Shared by the gateway tests. Names are built the way level 3 builds them, because the runner cannot read
# Terraform outputs.
# shellcheck shell=bash
PREFIX="${PREFIX:-lab}"
TENANT="${AZURE_TENANT_ID:?set AZURE_TENANT_ID}"
GATEWAY="https://$PREFIX-apim-aiservices-prd-ae.azure-api.net/openai"
FOUNDRY="https://$PREFIX-ais-aiservices-prd-ae.openai.azure.com/openai"
AUDIENCE="api://$TENANT/$PREFIX-aigateway"
API="api-version=2024-10-21"
DEPLOYMENT="gpt-5-mini"
BODY="$(mktemp)"
RESULTS="[]"

# Prints the HTTP status, or no-response if nothing came back in time. The body is left in $BODY.
http() {
  local code
  code="$(curl -s -o "$BODY" -w '%{http_code}' --max-time 20 "$@" || true)"
  if [ -z "$code" ] || [ "$code" = 000 ]; then echo no-response; else echo "$code"; fi
}

# record <id> <threat model ref> <what> <expected, a regex> <actual> [detail]
record() {
  local pass=false detail
  # Details never carry identifiers into the public log.
  detail="$(sed -E 's/[0-9a-fA-F]{8}(-[0-9a-fA-F]{4}){3}-[0-9a-fA-F]{12}/<guid>/g' <<<"${6:-}")"
  if [[ "$5" =~ ^($4)$ ]]; then pass=true; fi
  RESULTS="$(jq -c --arg id "$1" --arg ref "$2" --arg what "$3" --arg expect "$4" --arg actual "$5" \
    --arg detail "$detail" --argjson pass "$pass" '. + [$ARGS.named]' <<<"$RESULTS")"
  printf '%s %s: %s (expected %s, got %s) %s\n' "$1" "$([ "$pass" = true ] && echo PASS || echo FAIL)" \
    "$3" "$4" "$5" "$detail"
}

# Writes the results, then fails if any case failed.
finish() {
  jq -n --argjson r "$RESULTS" '{total: ($r | length), passed: ([$r[] | select(.pass)] | length), cases: $r}' > "$1"
  jq -e '.passed == .total' "$1" > /dev/null
}
