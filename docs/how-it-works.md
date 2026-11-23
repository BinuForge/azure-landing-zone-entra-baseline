# How this repository works

One page for engineers: what is where, who runs it, and how a change gets to Azure. Terms in **bold**
are in the [glossary](glossary.md).

## The idea

Everything is Terraform in this repository. You change code in a pull request, a pipeline shows you the
plan, a person approves it, and the pipeline applies exactly that plan. No one changes Azure or Entra in
the portal, and no pipeline holds a secret.

## What is where

| Folder | What it builds | Who runs it | How |
|---|---|---|---|
| `bootstrap/` | Budget, pipeline identities, their roles, GitHub environments, report store, security log workspace | You, once and after changes | `terraform apply` on your machine ([runbook](runbooks/bootstrap.md)) |
| `entra/bootstrap/` | The Entra pipelines' identities and Graph permissions | You | Same as bootstrap |
| `tfc/` | HCP Terraform workspaces and variable sets | You | Same as bootstrap |
| `azure/level-0-org/` | Management groups | Pipeline | `azure-l0.yml` |
| `azure/level-1-governance/` | Azure Policy baseline | Pipeline | `azure-l1.yml` |
| `azure/level-2-platform/` | Log Analytics, hub network, private DNS | Pipeline | `azure-l2.yml` |
| `azure/level-3-aiservices/` | Foundry, the APIM AI gateway, guardrails | Pipeline | `azure-l3.yml` |
| `azure/level-4-workloads/opsagent/` | The ops agent's read-only roles and test canary | Pipeline, run in HCP | `azure-l4.yml` |
| `entra/level-0-org/` | Persona groups | Pipeline | `entra-l0-org.yml` |
| `entra/level-0-privileged/` | Break-glass protection and PIM | You (CI plans only) | [runbook](runbooks/entra-privileged.md) |
| `entra/level-1-governance/` | Tenant defaults, authentication methods | Pipeline | `entra-l1-governance.yml` |
| `entra/level-1-ca/` | Conditional Access, report-only first | Pipeline | `entra-l1-ca.yml` |
| `agents/opsagent/` | The ops agent, standard-library Python | Pipeline | `opsagent.yml` |
| `tests/` | Live tests against the deployed lab | Pipeline | `gateway-tests.yml`, `agent-live-tests.yml` |

Higher levels build on lower ones and read their outputs, so deploy in order: Azure 0 to 4, then Entra
0 to 1. Teardown goes the other way.

The three roots you run by hand are **Tier 0**: they create the pipelines' own access, so a pipeline must
never be able to change them.

## How a change reaches Azure

1. **Branch and change.** Add or edit Terraform in one level, with a test (`tests/*.tftest.hcl`).
2. **Run the gates locally**: `pre-commit run --all-files`, then `terraform -chdir=<level> test`
   ([contributing](../CONTRIBUTING.md#local-gates)).
3. **Open a pull request.** CI runs the same gates, and the level's workflow posts its **plan** as a
   comment. The plan runs as the level's **plan identity**, which can read but not change anything.
4. **Read the plan.** If it destroys something, say why in the pull request.
5. **Merge.** The workflow plans again on `main` and waits for approval in the level's **apply
   environment**.
6. **Approve.** The **apply identity** applies the **saved plan**, so what runs is exactly what you read.

If the plan shows no changes, nothing waits for approval.

## Where state lives

Each level has its own **workspace** in HCP Terraform. For most levels Terraform runs on the GitHub runner
(**local execution**) and only the state is in HCP. Level 4 runs in HCP itself (**remote execution**)
with **dynamic credentials**. A level reads a lower level's outputs with `tfe_outputs`, never its whole
state.

## What costs money

Only level 2 to 4 resources cost anything, about AUD 3 a day in total, most of it API Management. Two
flags in `azure/level-3-aiservices/variables.tf` change it: `enable_apim` (default `true`) and
`enable_prompt_logging` (default `false`). `destroy.yml` removes levels 2 to 4; levels 0 and 1 and
bootstrap are free and stay ([cost](cost.md)).

## How you know it works

| Kind | What it proves | Where |
|---|---|---|
| Unit tests with mock providers | Each level builds what it should, and refuses what it should not | `<level>/tests/`, run on every pull request |
| Static gates | Formatting, lint, security scan, no secrets | `pr.yml` |
| Live tests | The controls hold on the real lab: gateway identity, kill switch, prompt injection | `gateway-tests.yml`, `agent-live-tests.yml` |
| **Evidence packs** | A signed record of what existed and what the tests showed | [`evidence/`](../evidence/) |

## Common tasks

| I want to | Do this |
|---|---|
| Deploy my own copy | [Quickstart](../QUICKSTART.md) |
| Change a policy, a role or a resource | The six steps above, in the level that owns it |
| Turn the AI gateway on or off, or stop all AI traffic | [AI gateway runbook](runbooks/ai-gateway.md) |
| Run the ops agent and read its report | [Ops agent](../agents/opsagent/README.md#run-the-agent) |
| Tear everything down | [Destroy runbook](runbooks/destroy.md) |
| Find the right runbook | [Runbook index](runbooks/README.md) |
| Know why something is built the way it is | [ADR index](adr/README.md) |
