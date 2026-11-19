# ADR-0016: Entra pipeline identities hold no Tier 0 Graph permission

- **Status:** Accepted
- **Date:** 2026-11-19

## Context

- The Entra baseline has four HCP workspaces (`tfc/workspaces.yaml`): level 0 `org` and `privileged`,
  level 1 `governance` and `ca`. Like Azure levels 0 to 3, they run locally on GitHub Actions with OIDC
  (ADR-0012).
- Entra objects are managed through Microsoft Graph. A pipeline identity's rights are Graph application
  permissions granted by admin consent; Azure RBAC does not apply.
- Some Graph permissions let an app grant itself anything. Microsoft's
  [permissions reference](https://learn.microsoft.com/en-us/graph/permissions-reference) warns that
  permissions which manage credentials or authorisation let an app act as others or raise its own
  privileges:
  - `RoleManagement.ReadWrite.Directory` assigns directory roles, including Global Administrator.
  - `AppRoleAssignment.ReadWrite.All` grants any app, itself included, any Graph permission.
  - `Application.ReadWrite.All` adds a credential to any app, then signs in as it.
- `Group.ReadWrite.All` changes every group that is not role-assignable or in a restricted management
  administrative unit, including groups that grant Azure access or exclude users from Conditional Access.
  `Group.Create` only creates groups; the app manages a group only if it named itself owner at creation
  ([Create group](https://learn.microsoft.com/en-us/graph/api/group-post-groups)).
- In a [restricted management administrative unit](https://learn.microsoft.com/en-us/entra/identity/role-based-access-control/admin-units-restricted-management),
  only principals with a role scoped to the unit can change its members. Global Administrator and Graph
  application permissions are blocked, and assigning a role on the unit is audited. The setting is fixed
  at creation, and members cannot be governed by PIM for Groups or access reviews.
- Checked on 2026-11-19 with `GET /subscribedSkus`: the tenant has no licences, so it is on Entra ID Free.
  Conditional Access and exporting sign-in logs need P1; PIM and Identity Protection need P2. The
  maintainer starts a 30-day P2 trial for the baseline.
- Creating Entra diagnostic settings needs Global Administrator or Security Administrator.
- Sign-in logs are personal data: names, IP addresses and locations. The ops workspace is read by the ops
  agent's runner (threat model C-06), whose output goes to a model.

## Options considered

### Who applies Tier 0 objects (directory roles, PIM, role-assignable groups, Conditional Access exclusions)

| Option | For | Against |
|---|---|---|
| A GitHub apply identity holding `RoleManagement.ReadWrite.Directory`, behind a reviewed environment | Every object comes from one gated path | A GitHub compromise or a hostile workflow change becomes Global Administrator. With one maintainer, the reviewer is the author |
| The maintainer applies locally; CI plans with a read-only identity | No automated path holds a Tier 0 write, and drift still shows on every pull request | A person runs the apply, and their machine is in scope |
| Portal only | Nothing to build | No review, no drift detection, no evidence |

### Where the Entra identities are created

| Option | For | Against |
|---|---|---|
| In `bootstrap/`, with the Azure identities | One person-run root | One run needs subscription Owner, root elevation and Global Administrator together, and an Azure change can touch Graph grants by accident |
| A separate root, `entra/bootstrap/`, sharing a module with Azure's | Each root needs only its own rights, and the identity boundary is visible in the layout | Two person-run roots and two states |

### How many identities

| Option | For | Against |
|---|---|---|
| One pair per level, as for Azure (ADR-0012) | Four identities | Level 1's apply identity would hold Conditional Access and tenant policy writes together |
| One pair per workspace | Each identity writes one area | Seven identities and environments instead of four |

### Group writes

| Option | For | Against |
|---|---|---|
| `Group.ReadWrite.All` | Simple, and can adopt groups made by hand | Can change every group in the tenant |
| `Group.Create`, with the app as owner | Changes only the groups it created | Cannot adopt existing groups; the app must name itself owner |

### Protecting the Conditional Access exclusion groups

| Option | For | Against |
|---|---|---|
| Plain security group | Simple | Any Groups Administrator, User Administrator or app with `Group.ReadWrite.All` can add itself to the bypass |
| Role-assignable group | Only Privileged Role Administrator and Global Administrator can change members | Creating one needs `RoleManagement.ReadWrite.Directory`; a Global Administrator changes it in one step |
| Restricted management administrative unit | Even a Global Administrator must first assign itself a role on the unit, which is audited. Graph permissions do not apply | Each membership change needs that scoped role; no PIM for Groups or access reviews on members |

### Where Entra's logs go

| Option | For | Against |
|---|---|---|
| The ops workspace | Already exists | The ops agent's runner reads it, and it is destroyed with level 2 |
| A security workspace in bootstrap's resource group | Only the maintainer reads it, and it outlives teardowns | One more workspace |

## Decision

1. Tier 0 objects live in `entra/level-0-privileged`: the restricted administrative unit, the Conditional
   Access exclusion groups, custom directory roles, role-assignable groups and PIM. CI plans it with a
   read-only identity, and the maintainer applies it locally, as for bootstrap. No GitHub identity holds a
   Tier 0 permission. The other three workspaces apply through gated pipelines.
2. Entra pipeline identities are created by their own person-run root, `entra/bootstrap/`, with state in
   `lab-entra-l0-bootstrap-prd`. It uses the azuread and github providers only, so it needs Global
   Administrator and repository admin, and no Azure role. The app, federated credential and GitHub
   environment come from `modules/github-pipeline-identity`, which `bootstrap/` can adopt later with
   `moved` blocks.
3. Each Entra workspace has its own pair, `lab-entra-<level>-<component>-plan` and `-apply`, and a GitHub
   environment for each, with ADR-0012's rules: plans from any branch, applies from `main` with a
   reviewer. `level-0-privileged` has a plan identity only. Entra environments hold no subscription ID.
4. Graph permissions are data, in `entra/bootstrap/graph.yaml`. The root grants them by ID from an allowed
   list in `entra/bootstrap/graph.tf`. The list leaves out every permission that can assign roles, grant
   permissions, add credentials, change every group or open consent, and
   `entra/bootstrap/tests/graph.tftest.hcl` checks that it stays that way.
5. The break-glass accounts and every Conditional Access exclusion group go in a restricted management
   administrative unit. To change a member, the maintainer assigns themselves Groups Administrator on the
   unit, makes the change and removes the role. Both steps are in the audit log.
6. The Azure bootstrap creates `lab-log-security-prd-ae` in its own resource group and sends Entra's audit,
   sign-in and risk logs there, behind `entra_diagnostics` (off until the tenant has P1 or P2). No
   pipeline identity holds a role that reads logs there.

`level-0-privileged` was kept out of CI's apply path for the same reason ADR-0012 kept identity creation
out of CI: with one maintainer, a reviewed pipeline adds no separation of duties, only a second way into Tier 0.

## Graph permissions

`entra/bootstrap/graph.yaml` is the source; this table explains each row.

| Identity | Application permissions | Why |
|---|---|---|
| `lab-entra-l0-org-plan` | `Group.Read.All`, `User.Read.All` | Read persona groups and their members |
| `lab-entra-l0-org-apply` | `Group.Create`, `Group.Read.All`, `User.Read.All` | Create persona groups it owns, with users as members |
| `lab-entra-l0-privileged-plan` | `AdministrativeUnit.Read.All`, `Group.Read.All`, `User.Read.All`, `RoleManagement.Read.Directory`, `RoleManagementPolicy.Read.Directory`, `RoleEligibilitySchedule.Read.Directory`, `RoleAssignmentSchedule.Read.Directory`, and the three PIM for Groups reads | Read what the Tier 0 workspace owns, and check the break-glass accounts still hold Global Administrator |
| `lab-entra-l1-governance-plan` | `Policy.Read.All` | |
| `lab-entra-l1-governance-apply` | `Policy.Read.All`, `Policy.ReadWrite.AuthenticationMethod`, `Policy.ReadWrite.Authorization`, `Policy.ReadWrite.CrossTenantAccess`, `Policy.ReadWrite.ConsentRequest` | Authentication methods; default user permissions and user consent; cross-tenant defaults; the admin consent workflow |
| `lab-entra-l1-ca-plan` | `Policy.Read.All` | |
| `lab-entra-l1-ca-apply` | `Policy.Read.All`, `Policy.ReadWrite.ConditionalAccess` | Microsoft's least-privileged pair for policies, named locations and authentication strengths |

Never granted to a pipeline: `RoleManagement.ReadWrite.Directory` and every PIM write,
`AppRoleAssignment.ReadWrite.All`, `Application.ReadWrite.All` and `.OwnedBy`, `Directory.ReadWrite.All`,
`Group.ReadWrite.All`, `GroupMember.ReadWrite.All`, `AdministrativeUnit.ReadWrite.All`,
`User.ReadWrite.All`, `UserAuthenticationMethod.ReadWrite.All` and `Policy.ReadWrite.PermissionGrant`.
User consent is turned off through the authorisation policy, so no custom consent policy is needed.

## Risks accepted

| Risk | Why it is accepted | Mitigation, or how we would notice |
|---|---|---|
| The Conditional Access identity can switch every policy off, or drop an exclusion | Writing policies is its job | Applies need a reviewed plan from `main`. Plan tests check every policy excludes the break-glass group. The policy change appears in the audit log in the security workspace |
| The governance identity can loosen authentication methods or cross-tenant access | Same: it is its job | Same gates; Maester checks the live settings (day 2) |
| `Policy.Read.All` on plan identities shows an attacker the tenant's Conditional Access gaps | Plans need it, and plan environments accept any branch so pull requests can plan | Only the maintainer can push branches; forks get no environment secrets |
| The maintainer applies Tier 0 objects as a standing Global Administrator | One person; the break-glass accounts are the only other administrators | PIM-eligible Privileged Role Administrator once level-0-privileged builds PIM; at a bank, a privileged access workstation |
| Entra logs are capped at 0.5 GB a day | Keeps the lab's cost fixed | A flood could stop logging for the day. At a bank, no cap, and a SIEM with longer retention |
| The P2 trial ends after 30 days | Free account | Conditional Access, PIM and log export need a licence again. Recorded in `docs/cost.md`; the Entra levels are torn down or bought for before the trial ends |

## Consequences

- Easier: each Entra identity's reach is one row of data, and a Tier 0 permission cannot be granted
  without changing the allowed list, which a test reads.
- Harder: two person-run roots instead of one. Tier 0 changes need the maintainer at their own machine, and a membership change in the
  restricted unit takes two extra audited steps.
- At bank scale: `entra/bootstrap` lives in the identity team's repository with its own approvers, and a separate Tier 0 pipeline on a privileged access runner with two-person approval;
  workload identity Conditional Access on every pipeline identity (Workload ID Premium); Graph activity
  logs to the SIEM; quarterly access reviews of every Graph grant.
