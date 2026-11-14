#!/usr/bin/env bash
# Signs the az CLI in as the job environment's identity with GitHub OIDC. Used instead of a third-party
# login action, so no outside code handles the token. The job needs `id-token: write`.
#
# Needs AZURE_CLIENT_ID, AZURE_TENANT_ID and AZURE_SUBSCRIPTION_ID from the environment.
set -euo pipefail

: "${AZURE_CLIENT_ID:?}" "${AZURE_TENANT_ID:?}" "${AZURE_SUBSCRIPTION_ID:?}"
: "${ACTIONS_ID_TOKEN_REQUEST_URL:?the job needs id-token: write}"

token="$(curl -sSf -H "Authorization: bearer $ACTIONS_ID_TOKEN_REQUEST_TOKEN" \
  "$ACTIONS_ID_TOKEN_REQUEST_URL&audience=api://AzureADTokenExchange" | jq -r .value)"
echo "::add-mask::$token"

az login --service-principal -u "$AZURE_CLIENT_ID" -t "$AZURE_TENANT_ID" \
  --federated-token "$token" --allow-no-subscriptions -o none
az account set --subscription "$AZURE_SUBSCRIPTION_ID"
