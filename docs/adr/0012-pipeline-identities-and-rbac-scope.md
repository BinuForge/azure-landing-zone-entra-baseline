# ADR-0012: Pipeline identities and RBAC scope

- **Status:** Accepted
- **Date:** 2026-11-14

## Context

- Each level deploys with two Entra identities: a read-only plan identity and an apply identity
  (`docs/naming.md`). Identities are per level, not per workspace, so the three level 2 workspaces share
  one pair.
- Platform levels authenticate from GitHub Actions with OIDC. The federated credential subject uses the
  repository's immutable IDs and the environment name, checked on 2026-11-14:

  ```sh
  gh api repos/BinuForge/azure-landing-zone-entra-baseline/actions/oidc/customization/sub
  # sub_claim_prefix: repo:BinuForge@62524369/azure-landing-zone-entra-baseline@1457263610
  ```

  A subject therefore looks like `<prefix>:environment:lab-azure-l2-apply`. Renaming or recreating the
  repository breaks every credential, which is intended.
- Level 4 runs remotely in HCP Terraform and authenticates with HCP dynamic credentials, with separate
  plan and apply identities matched on `run_phase`.
- An identity that can create identities and assign roles can grant itself anything. It is the top of
  the privilege chain.
- There is one subscription (ADR-0004), so resource groups are the only boundary between levels.
- The free account's daily admin is a Global Administrator, which gives no Azure RBAC rights until
  access is elevated.

## Options considered

### Who creates the pipeline identities

| Option | For | Against |
|---|---|---|
| Bootstrap creates all of them, run by a person | Granting access never happens on an automated path | Adding a level needs a manual bootstrap run |
| Bootstrap creates level 0's identity; level 0 creates the rest | Every identity is IaC with gates and drift detection | The level 0 pipeline can mint an Owner, so a GitHub compromise becomes a tenant compromise |
| Identity pipeline with constrained role assignment | Automated, and it can only grant an approved list of roles | Needs a separate owner and approver to add real value |

### How far each identity reaches

| Option | For | Against |
|---|---|---|
| Each level's apply identity scoped to resource groups that bootstrap creates | The only real boundary between levels in one subscription | A few cross-group grants are needed |
| Contributor on the subscription for platform levels | Simple | Any level can change any other |

## Decision

1. Bootstrap, run by a person with access elevated only for that run, creates every pipeline identity,
   its federated credentials and its role assignments, from `tfc/workspaces.yaml`.
2. Bootstrap creates each level's resource group. Apply identities get roles on those groups only, plus
   the named cross-group grants below.
3. No identity can assign roles freely. Where a level must assign a role, it holds Role Based Access
   Control Administrator with a condition naming the only roles it may assign.
4. Provider registration is done once by bootstrap. Level providers set
   `resource_provider_registrations = "none"`, so no level needs subscription-wide write rights.
5. No credential enters Terraform state. Bootstrap creates environments and variables; a script sets the
   HCP token and the plan encryption key with `gh secret set`. Tenant and subscription IDs are identifiers,
   not credentials, so bootstrap stores them as environment secrets: Actions prints variable values in
   logs, and logs are public on this repository.

The person-run bootstrap was chosen because, with one maintainer, a separate identity pipeline adds no
separation of duties. It would only add a second automated path to Tier 0.

## Roles, this week

Scope "root" is the tenant root management group. Resource group names follow `docs/naming.md`, region
`ae`.

| Identity | Role | Scope | Why |
|---|---|---|---|
| `lab-azure-l0-plan` | Reader | root | Read management groups and placement |
| `lab-azure-l0-apply` | Management Group Contributor | root | Create the hierarchy |
| `lab-azure-l1-plan` | Reader | root | Read policy state |
| `lab-azure-l1-apply` | Resource Policy Contributor | root | Policy definitions and assignments. Deny and audit only, so no policy identity needs roles |
| `lab-azure-l2-plan` | Reader | management, connectivity, DNS groups | |
| `lab-azure-l2-apply` | Contributor | management group (resource group) | Log Analytics |
| `lab-azure-l2-apply` | Network Contributor | connectivity group | Hub network |
| `lab-azure-l2-apply` | Private DNS Zone Contributor | DNS group | Zones, and links to the hub |
| `lab-azure-l3-plan` | Reader | AI services, connectivity and DNS groups | Plans read the peering and zone links that level 3 owns in the hub's groups |
| `lab-azure-l3-apply` | Contributor | AI services group | Foundry, APIM, prompt workspace |
| `lab-azure-l3-apply` | Custom `lab-role-spoke-network-join`: peer with the hub and register private endpoint records | connectivity and DNS groups | Spoke joins the hub without owning it |
| `lab-azure-l3-apply` | Custom `lab-role-log-linker`: `workspaces/read` and `workspaces/sharedKeys/action` only | management group (resource group) | Diagnostic settings to the ops workspace need it; local auth is off there, so the keys are unusable |
| `lab-azure-l3-apply` | Role Based Access Control Administrator, condition: may assign only Cognitive Services OpenAI User and Log Analytics Reader, and only to service principals | AI services group | Give APIM's identity the model role (ADR-0008) |
| `lab-azure-l3-apply` | Role Based Access Control Administrator, condition: may assign only Log Analytics Reader, and only to service principals | management group (resource group) | Give the prompt-query alert's identity read on the ops workspace (threat model C-16) |
| `lab-azure-l4-plan` | Reader | subscription | HCP dynamic credentials, `run_phase:plan`. Plans read the runner's role assignments, which sit at several scopes |
| `lab-azure-l4-apply` | Contributor | ops agent group | HCP dynamic credentials, `run_phase:apply` |
| `lab-azure-l4-apply` | Role Based Access Control Administrator, condition: may assign only Reader, Cost Management Reader and Log Analytics Reader, and only to service principals | subscription | Give the runner identity its read roles |
| `lab-azure-l4-opsagent-run` | Custom `lab-role-report-writer`: blob write and add only, no read, list or delete | report store container | The ops agent's runner adds reports (ADR-0015). Its read roles come from level 4 (threat model C-06) |

Moving a subscription needs `roleAssignments/write` and `delete` on it, which in practice means Owner
([move management groups and subscriptions](https://learn.microsoft.com/en-us/azure/governance/management-groups/manage)).
So bootstrap, not level 0, places the subscription in `lab-mg-corp`, and also sets the hierarchy
settings: new subscriptions land in `lab-mg-sandbox`, and creating a management group needs write rights
at the root.

The maintainer's own standing Azure access:

| Principal | Role | Scope | Why |
|---|---|---|---|
| Maintainer | Owner (from the free account sign-up) | subscription | Runs bootstrap |
| Maintainer | Management Group Reader | `lab-mg-root` | See the hierarchy; Global Administrator alone shows nothing |
| Maintainer | Management Group Contributor | `lab-mg-corp` | Keep the subscription placed there |
| Maintainer | Custom `lab-role-hierarchy-settings`: `managementgroups/settings/read` and `write` only | root | Hierarchy settings need these at the root, and no built-in role short of Owner grants them |

Entra level identities need Microsoft Graph permissions and are added when the Entra baseline is built.

## Risks accepted

| Risk | Why it is accepted | Mitigation, or how we would notice |
|---|---|---|
| The person running bootstrap holds User Access Administrator at root during the run | Someone has to create the first grants | Elevation switched on for the run only, then off; recorded in the runbook |
| Bootstrap state holds identity and role details | It is in HCP with no secrets in it | Workspace access limited to the owners team |
| A role assignment condition is written wrongly and allows more than intended | Conditions are new to most reviewers | A test tries to assign Owner with each constrained identity and expects 403 |
| The maintainer holds standing Azure grants as a user, not through PIM and a group | One maintainer, and a Global Administrator can elevate at any time anyway | Read by default, write on one management group, one two-action custom role; at a bank, PIM-eligible group assignments |

## Consequences

- Easier: each level's reach is visible in one table and testable.
- Harder: a new level or resource group means a bootstrap run.
- At bank scale this changes to an identity pipeline owned by the identity team, with its own approvers,
  role assignment conditions on every delegation, and quarterly access reviews of all pipeline
  identities.
