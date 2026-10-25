# ADR-0002: HCP Terraform access model on the Free tier

- **Status:** Accepted
- **Date:** 2026-10-25

## Context

The design calls for one identity per level, each able to write its own state and read only the
outputs of the levels below it. In HCP Terraform that is done with teams and team tokens.

The organisation's entitlement set was checked on 2026-10-25 (read-only API call):

```sh
curl -s -H "Authorization: Bearer $TOKEN" \
  https://app.terraform.io/api/v2/organizations/<org>/entitlement-set
```

| Entitlement | Value | Effect |
|---|---|---|
| Plan | Free | 500 managed resources, 1 concurrent run |
| `teams` | `false` | Only the built-in owners team exists; no per-level teams or team tokens |
| `private-module-registry` | `true` | Local modules can be published |
| `policy-set-limit` / `policy-limit` | 1 / 5 | One small policy set is possible later |
| `audit-logging` | `false` | No audit trail API |

HashiCorp's documentation disagrees with itself here: the plans page lists team management under
Free, while the teams page says Essentials and above. The entitlement set is what the service
enforces, so it is the source of truth.

Dynamic provider credentials are not an entitlement and are not gated on Free. They are proven with a
real run in the workload phase.

Token options without teams:

| Token | State access for local runs | Scope |
|---|---|---|
| User token | Yes | Tied to a person; leaves with them |
| Organisation token | TODO: confirm in bootstrap. It cannot start runs or create configuration versions | Organisation-wide |
| Owners team token | Yes | Organisation owner rights |

## Decision

1. Projects, workspaces and variable sets are still managed as code in `tfc/`, so the design is ready
   for a paid tier. Team resources are not created.
2. CI uses one **owners team token**, stored only as a GitHub *environment* secret
   (`TF_TOKEN_APP_TERRAFORM_IO`), never as a repository secret.
3. The token is **Tier 0** for HCP Terraform and is treated that way:
   - organisation maximum token lifetime of 30 days; a rotation runbook is added in the bootstrap phase;
   - only reachable from GitHub environments: plan environments accept branches in this repository,
     apply environments accept `main` only and need a required reviewer;
   - pull requests from forks never receive environment secrets.
4. State sharing is still declared per workspace (`remote_state_consumer_ids`, `global_remote_state =
   false`), derived from the `reads` list in `tfc/workspaces.yaml`.

## Consequences

- **Accepted risk:** a leaked token can read and write every workspace's state. Per-level isolation of
  *Azure and Entra* permissions is unaffected, because those come from the per-level OIDC identities,
  not from HCP.
- `remote_state_consumer_ids` is enforced for **remote** runs (level 4). Local runs read outputs with
  the CI token, which can read everything, so for levels 0-3 the allow-list documents intent rather
  than enforcing it. Tests keep it accurate so it enforces on day one of a paid tier.
- The allow-list is generated from `tfc/workspaces.yaml`; the Mermaid graph
  (`docs/architecture/dependency-graph.md`) mirrors the same file and is updated in the same PR.

### Paid-tier design (Essentials or above)

| Team | Workspace access | Token stored in |
|---|---|---|
| `lab-azure-l0` ... `lab-azure-l3` | Write on own workspace; read outputs on each workspace in `reads` | That level's plan and apply environments |
| `lab-entra-l0`, `lab-entra-l1` | Same pattern | Same pattern |
| `lab-platform-admins` | Manage the `tfc/` root | Local use only |

Changing tier means adding `tfe_team` and `tfe_team_access` resources driven by the same `reads` list,
plus one token per level. No workspace or pipeline is renamed.

## Alternatives considered

| Option | Why not |
|---|---|
| User token in CI | Ties automation to a person; breaks when they leave or change password policy. |
| Pay for Essentials | Teams are the only gap; the lab stays free and the gap is documented here. |
| Azure Storage backend | Solves isolation with Azure RBAC per container, at the cost of `tfe_outputs`, the registry and dynamic credentials. Documented fallback: ADR-0003. |
