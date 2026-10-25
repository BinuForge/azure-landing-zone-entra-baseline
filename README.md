# Azure landing zone and Entra ID baseline as code

A right-sized Azure landing zone and Entra ID security baseline for a regulated organisation of
300 to 1,000 staff: one tenant, one primary region and one DR region. Everything is Terraform, delivered
through gated pipelines, and deployed for real in a dedicated lab tenant.

> **Status:** work in progress. Phase 1 (repository skeleton and PR gates) is under way.

## What it shows

- **Layered platform.** Azure levels 0-4 and Entra ID levels 0-1, each in its own HCP Terraform
  workspace. Higher levels read lower levels' outputs; never the reverse.
- **Least-privilege delivery.** Every level has a read-only plan identity and a write apply identity,
  federated to GitHub Actions with OIDC. No client secrets exist.
- **Gated change.** PR gates run offline (format, validate, lint, IaC scan, secret scan, tests with
  mock providers). Applies run only from `main`, from a saved and encrypted plan, after a human
  approves.
- **Identity baseline.** Conditional Access from Microsoft's templates (report-only first), PIM as
  code, break-glass accounts that Terraform reads but never creates, and tests that prove them.
- **Cost discipline.** The default deployment costs under USD 5 a day; anything costly is behind a
  flag that defaults to off and is reset nightly.

## Repository layout

| Path | Purpose |
|---|---|
| `bootstrap/` | One-off setup: HCP seed, pipeline identities, federated credentials, budgets |
| `tfc/` | HCP Terraform projects, workspaces and variable sets, from YAML |
| `modules/` | Small local modules where Azure Verified Modules do not fit |
| `azure/` | Azure platform levels 0-4 |
| `entra/` | Entra ID levels 0-1 and break-glass checks |
| `tests/` | Post-deployment tests (Maester, Pester) |
| `docs/` | Architecture, ADRs, runbooks, cost |

## Key documents

- [Naming convention](docs/naming.md)
- [Workspace dependency graph](docs/architecture/dependency-graph.md)
- [Cost and HCP resource count](docs/cost.md)
- [Architecture decision records](docs/adr/)
- [Local setup](docs/runbooks/local-setup.md)

## Licensing notes

Features that need Entra ID P2 or Workload Identities Premium are marked where they are used, and
are behind flags so the code still deploys without them.

## Scope

This is a personal lab built on my own tenant and subscription. It contains nothing from any employer.
Where it maps controls to regulatory frameworks, it says the design *supports* a control, never that it
*complies*.
