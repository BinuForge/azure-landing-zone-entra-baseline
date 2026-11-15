# tests

Tests that run against the real tenant. Terraform unit tests with mock providers live next to the code
they test, in `<root>/tests/`.

| Folder | What it proves | How it runs |
|---|---|---|
| `policy/` | Level 1 policies refuse non-compliant resources, and the study waiver allows only what it should. Each case asks Azure Policy which restrictions it would place on a proposed resource (`checkPolicyRestrictions`): nothing is created, and Reader is enough | In the evidence workflow, as `lab-azure-l0-plan`. Locally: `AZURE_SUBSCRIPTION_ID=<id> bash tests/policy/run.sh` |

Maester and Pester tests for the Entra baseline are added with it.
