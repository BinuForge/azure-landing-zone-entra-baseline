# tests

Tests that run against the real tenant. Terraform unit tests with mock providers live next to the code
they test, in `<root>/tests/`.

| Folder | What it proves | How it runs |
|---|---|---|
| `policy/` | Level 1 policies refuse non-compliant resources, and the study waiver allows only what it should. Each case asks Azure Policy which restrictions it would place on a proposed resource (`checkPolicyRestrictions`): nothing is created, and Reader is enough | In the evidence workflow, as `lab-azure-l0-plan`. Locally: `AZURE_SUBSCRIPTION_ID=<id> bash tests/policy/run.sh` |
| `gateway/` | The AI gateway's controls on the live deployment: who can get a token, who holds a role on the model, what the gateway refuses, the token limit and the kill switch (GW-01 to GW-13) | `gateway-tests.yml`, each job as the identity whose access it tests. Needs `enable_apim = true` |
| `agent/` | The ops agent's controls on the live lab: planted attacks on the canary, a hostile request, the runner's roles and refused writes, sign-in from outside its environment, the prompt workspace, and one run ID through the logs (threat model T-01 to T-03, T-07 to T-10, T-12, T-13) | `agent-live-tests.yml`, each job as the identity whose access it tests. Needs `enable_apim = true` and level 4 |

Maester and Pester tests for the Entra baseline are added with it.
