#!/usr/bin/env bash
# Tries to sign in as the ops agent's runner from a job outside its environment (threat model T-07). The
# runner's federated credential trusts one subject, this repository's lab-azure-l4-opsagent-run
# environment, and the environment accepts main only. So the job's own GitHub token, whose subject names a
# branch and no environment, must be refused by Entra.
#
# Needs a job with `id-token: write` and `actions: read`, and no environment.
#
#   AZURE_TENANT_ID=<id> RUNNER_CLIENT_ID=<id> GH_TOKEN=<token> bash tests/agent/outside.sh results.json
set -euo pipefail
# shellcheck source=tests/gateway/lib.sh
source "$(dirname "$0")/../gateway/lib.sh"

OUT="${1:?results file}"
CLIENT="${RUNNER_CLIENT_ID:?set RUNNER_CLIENT_ID}"
REPO="${GITHUB_REPOSITORY:?run in GitHub Actions}"
: "${ACTIONS_ID_TOKEN_REQUEST_URL:?the job needs id-token: write}"

assertion="$(curl -sSf -H "Authorization: bearer $ACTIONS_ID_TOKEN_REQUEST_TOKEN" \
  "$ACTIONS_ID_TOKEN_REQUEST_URL&audience=api://AzureADTokenExchange" | jq -r .value)"
echo "::add-mask::$assertion"
# The subject names the repository and branch only, which are public.
subject="$(python3 -c 'import base64, json, sys; p = sys.stdin.read().split(".")[1]; print(json.loads(base64.urlsafe_b64decode(p + "=" * (-len(p) % 4)))["sub"])' <<<"$assertion" || true)"

code="$(http "https://login.microsoftonline.com/$TENANT/oauth2/v2.0/token" -X POST \
  --data-urlencode "client_id=$CLIENT" --data-urlencode grant_type=client_credentials \
  --data-urlencode scope=https://management.azure.com/.default \
  --data-urlencode client_assertion_type=urn:ietf:params:oauth:client-assertion-type:jwt-bearer \
  --data-urlencode "client_assertion=$assertion")"
# A token, if one came back, is never printed.
if jq -e '.access_token' "$BODY" > /dev/null 2>&1; then
  echo "::add-mask::$(jq -r .access_token "$BODY")"
  actual=issued
else
  actual="$(jq -r '.error_codes[0] // empty' "$BODY" 2>/dev/null || true)"
  actual="AADSTS${actual:-error $code}"
fi
: > "$BODY"
record T-07a C-10 "A job outside the runner's environment cannot sign in as the runner" AADSTS700213 "$actual" \
  "job subject ${subject:-unknown}"

policy="$(gh api "repos/$REPO/environments/lab-azure-l4-opsagent-run" --jq .deployment_branch_policy)"
branches="$(gh api "repos/$REPO/environments/lab-azure-l4-opsagent-run/deployment-branch-policies" \
  --jq '[.branch_policies[] | "\(.type):\(.name)"] | join(",")')"
actual="$branches"
if [ "$(jq -r .custom_branch_policies <<<"$policy")" != true ]; then actual="any branch"; fi
record T-07b C-10 "The runner's environment accepts main only" "branch:main" "$actual"

finish "$OUT"
