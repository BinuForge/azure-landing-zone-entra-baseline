# tests

Tests that run against the real tenant. Terraform unit tests with mock providers live next to the code
they test, in `<root>/tests/`.

| Folder | What it proves | How it runs |
|---|---|---|
| `policy/` | Level 1 policies refuse non-compliant deployments, and the study waiver allows what it should. Each case validates a deployment, so the policy engine runs and nothing is created | In the evidence workflow, as `lab-azure-l0-plan` with the validate-only role. Locally: `bash tests/policy/run.sh` |

Maester and Pester tests for the Entra baseline are added with it.
