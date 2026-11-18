# AI gateway

The APIM gateway in level 3 is the only identity allowed to call the model (ADR-0008). This page covers
turning it on and off, calling it, and the kill switch.

## Turn it on or off

`enable_apim` in `azure/level-3-aiservices/variables.tf` is `true` during the test sessions and `false`
otherwise. Changing it is a pull request; the `azure-l3` pipeline then plans and applies it after
approval. `destroy.yml` removes the gateway with the rest of level 3.

| | On | Off |
|---|---|---|
| Creates or removes | Public IP, APIM Developer, named value, API, one operation, policy, APIM's role on Foundry, diagnostics | The same |
| Takes | 30 to 60 minutes | 30 minutes or more |
| Costs | About USD 1.80 a day | Nothing |

The public IP is allowed by the level 1 exemption `lab-apim-public-ip`, category Mitigated.

## Call it

Callers need an Entra token for the gateway with the `AI.Invoke` role. Only `lab-azure-l4-opsagent-run`
holds it (bootstrap/gateway.tf). From a job signed in as that identity:

```sh
# The runner cannot read Terraform outputs, so it builds the same values level 3 does.
AUDIENCE="api://$AZURE_TENANT_ID/lab-aigateway"
GATEWAY="https://lab-apim-aiservices-prd-ae.azure-api.net/openai"
TOKEN="$(az account get-access-token --resource "$AUDIENCE" --query accessToken -o tsv)"

curl -s "$GATEWAY/deployments/gpt-5-mini/chat/completions?api-version=2024-10-21" \
  -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" \
  -H "x-correlation-id: $GITHUB_RUN_ID" \
  -d '{"messages":[{"role":"user","content":"ping"}],"max_completion_tokens":20}'
```

| Response | Meaning |
|---|---|
| 200 | Called the model through the gateway |
| 401 | No token, wrong audience, or no `AI.Invoke` role |
| 429 | Over the caller's token limit |
| 503 `AI gateway disabled` | The kill switch is on |
| 400 with a content filter error | The guardrail blocked the prompt or the response |

## Kill switch

Stops every model call at the gateway within seconds (threat model C-20, test T-15). It is a named value
the policy checks on every request. Terraform ignores its value on purpose, so flipping it is not drift
and a later apply does not undo it.

```sh
RG=lab-rg-aiservices-prd-ae
APIM=lab-apim-aiservices-prd-ae

# Stop all AI traffic
az apim nv update -g "$RG" -n "$APIM" --named-value-id ai-kill-switch --value true

# Resume
az apim nv update -g "$RG" -n "$APIM" --named-value-id ai-kill-switch --value false
```

Record every use: when, why, and when it was resumed. A second line of defence, slower but independent of
APIM, is removing APIM's `Cognitive Services OpenAI User` role on the Foundry account.

The lab flips the switch with the level 3 apply identity, behind an approval. At bank scale it would be a
dedicated gateway-operator role, activated through PIM, that can only write named values, so the people
who can stop AI traffic do not also hold deploy rights.

## Follow a run through the logs

The gateway logs every call to the ops workspace: the caller's `x-correlation-id` (the GitHub run ID) and
the request ID it sent on to Foundry, never a body or the caller's IP (ADR-0010, threat model C-22).
Records arrive 5 to 15 minutes after the call. The forwarded ID is a GUID, so it lands in a `_g` column.

```kusto
AzureDiagnostics
| where ResourceProvider == "MICROSOFT.APIMANAGEMENT" and Category == "GatewayLogs"
| where requestHeaders_x_correlation_id_s == "<run-id>"
| project TimeGenerated, responseCode_d, backendRequestHeaders_x_ms_client_request_id_g
```

Foundry's usage log does not record that ID, so a gateway record joins Foundry's by time and deployment
(threat model T-13c).

## Test it

Run `gateway-tests` from the Actions tab with a label such as `2026-11-15-gateway`. It runs 13 cases as
three identities, and the kill switch job waits for approval in `lab-azure-l3-apply`. Then bring the
signed results in:

```sh
bash .github/scripts/pull-evidence.sh <run-id> <label> gateway-tests.yml
```

The ops agent's controls, which depend on the gateway, are tested by `agent-live-tests` (`tests/README.md`).
