# Architecture decision records

One record per significant decision: the context, the options considered, the decision, the risks
accepted, and what changes at bank scale. New records start from [the template](0000-template.md).

| ADR | Decision | Area | Status | Date |
|---|---|---|---|---|
| [0001](0001-pin-providers-tools-and-actions.md) | Pin providers, tools and CI actions | Delivery | Accepted | 2026-10-25 |
| [0002](0002-hcp-terraform-free-tier-access-model.md) | HCP Terraform access model on the Free tier | Delivery | Accepted | 2026-10-25 |
| [0003](0003-state-in-hcp-terraform-with-azure-storage-fallback.md) | State in HCP Terraform, with Azure Storage as the fallback | Delivery | Accepted | 2026-10-25 |
| [0004](0004-one-subscription-on-the-free-account.md) | One subscription on the free account, with no upgrade | Platform | Accepted | 2026-11-04 |
| [0005](0005-add-azapi-and-github-providers.md) | Add the azapi and GitHub providers | Delivery | Accepted | 2026-11-05 |
| [0006](0006-solo-maintainer-approvals.md) | Approvals with a single maintainer | Delivery | Accepted | 2026-11-05 |
| [0007](0007-ai-services-as-a-shared-landing-zone.md) | AI services as a shared landing zone | AI | Accepted | 2026-11-14 |
| [0008](0008-gateway-enforced-by-identity.md) | The AI gateway is enforced by identity | AI | Accepted | 2026-11-14 |
| [0009](0009-model-deployment-type-and-residency.md) | Model deployment type and residency | AI | Accepted | 2026-11-14 |
| [0010](0010-prompt-content-is-sensitive-data.md) | Prompt content is sensitive data | AI | Accepted | 2026-11-14 |
| [0011](0011-evidence-as-code.md) | Evidence as code | Assurance | Accepted | 2026-11-14 |
| [0012](0012-pipeline-identities-and-rbac-scope.md) | Pipeline identities and RBAC scope | Identity | Accepted | 2026-11-14 |
| [0013](0013-levels-read-lower-levels-through-tfe-outputs.md) | Levels read lower levels through tfe_outputs | Delivery | Accepted | 2026-11-15 |
| [0014](0014-encryption-keys-follow-data-classification.md) | Encryption keys follow data classification | Platform | Accepted | 2026-11-15 |
| [0015](0015-ops-agent-report-store.md) | The ops agent's report store is write-only, identity-only and outlives teardowns | AI | Accepted | 2026-11-15 |
| [0016](0016-entra-pipeline-identities-and-graph-permissions.md) | Entra pipeline identities hold no Tier 0 Graph permission | Identity | Accepted | 2026-11-19 |
| [0017](0017-conditional-access-baseline.md) | Conditional Access baseline starts report-only and excludes one protected group | Identity | Accepted | 2026-11-19 |
| [0018](0018-entra-tenant-governance-defaults.md) | Tenant defaults deny by default, and passkeys replace phone methods | Identity | Accepted | 2026-11-19 |
| [0019](0019-pim-applied-by-a-person-checked-by-terraform.md) | PIM is applied by a person with a delegated token and checked by Terraform | Identity | Accepted | 2026-11-22 |

ADR-0004 is under review: the free account's credit ends on 2026-11-24, and the choice is to let the
subscription lapse or move to pay-as-you-go. The outcome will be a new record that supersedes it.

[`real-world/`](real-world/) holds decisions of the kind an architect makes at a regulated organisation, where
the forces differ: more teams, change control, auditors and existing estates.
