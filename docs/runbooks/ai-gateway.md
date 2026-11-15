# AI gateway

The APIM gateway in level 3 is the only identity allowed to call the model (ADR-0008). This page covers
turning it on and off, calling it, and the kill switch.

## Turn it on or off

`enable_apim` in `azure/level-3-aiservices/variables.tf` defaults to `false`. Changing the default is a
pull request; the `azure-l3` pipeline then plans and applies it after approval.

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
AUDIENCE="$(terraform -chdir=azure/level-3-aiservices output -raw gateway_audience)"
GATEWAY="$(terraform -chdir=azure/level-3-aiservices output -raw gateway_url)"
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
