#!/usr/bin/env bash
# Turns the gateway's kill switch on, times how long until calls stop (threat model T-15), then turns it
# off again. Run as an identity that can change the gateway (lab-azure-l3-apply in the workflow, which
# waits for approval). The probes need no token: the switch is checked before identity, so it stops
# every caller at once.
#
#   AZURE_TENANT_ID=<id> bash tests/gateway/kill-switch.sh results.json
set -euo pipefail
# shellcheck source=lib.sh
source "$(dirname "$0")/lib.sh"

OUT="${1:?results file}"
RG="$PREFIX-rg-aiservices-prd-ae"
NAME="$PREFIX-apim-aiservices-prd-ae"

probe() {
  http "$GATEWAY/deployments/$DEPLOYMENT/chat/completions?$API" -X POST -H "Content-Type: application/json" -d '{}'
}

set_switch() {
  az apim nv update -g "$RG" -n "$NAME" --named-value-id ai-kill-switch --value "$1" -o none
}

# wait_for <status> <seconds>: probes every 2 seconds, prints the last status seen.
wait_for() {
  local start=$SECONDS code
  while :; do
    code="$(probe)"
    if [ "$code" = "$1" ] || (( SECONDS - start >= $2 )); then echo "$code"; return; fi
    sleep 2
  done
}

record GW-11 C-20 "With the switch off, the gateway asks for identity" 401 "$(probe)"

trap 'set_switch false || echo "::error::The kill switch may still be on. Turn it off: docs/runbooks/ai-gateway.md"' EXIT
start=$SECONDS
set_switch true
code="$(wait_for 503 120)"
took=$((SECONDS - start))
if [ "$code" = 503 ] && [ "$took" -gt 60 ]; then code=503-late; fi
record GW-12 T-15 "The kill switch stops every call within 60 seconds" 503 "$code" "${took}s from the switch command"

start=$SECONDS
set_switch false
trap - EXIT
record GW-13 C-20 "Turning the switch off restores the gateway" 401 "$(wait_for 401 120)" "$((SECONDS - start))s"

finish "$OUT"
