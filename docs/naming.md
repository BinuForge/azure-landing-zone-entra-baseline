# Naming convention

Every name in this repository follows this page. Code enforces the patterns where it can
(Terraform preconditions, variable validation, tests); everything else is checked in review.

## Design rules

- **Lowercase, hyphen-separated** unless a service forbids hyphens (storage accounts) or the name is
  shown to people as a title (Conditional Access policies).
- **Most general to most specific**: prefix, then area, then level, then component, then environment.
  Sorting a list of names groups related things together.
- **No organisation names, cost centres or IP ranges in names.** They change; names should not.
- **Prefix** is a variable (`prefix`, default `lab`). A second deployment changes the prefix, not the code.

## Tokens

| Token | Values | Notes |
|---|---|---|
| `<prefix>` | `lab` | 2-5 lowercase letters. |
| `<area>` | `azure`, `entra`, `tfc` | `tfc` is the HCP Terraform configuration itself. |
| `<level>` | `l0` to `l4` | Lower levels never read higher levels. |
| `<component>` | `org`, `governance`, `management`, `connectivity`, `dns`, `landingzones`, `aiservices`, `privileged`, `ca`, `core`, `bootstrap`, or a workload name such as `opsagent` | Lowercase letters only, no hyphens. |
| `<env>` | `prd`, `np` | Platform levels are a single shared instance and use `prd`. Workloads use `np` (non-production) or `prd`. |
| `<region>` | `ae` (australiaeast, primary), `ase` (australiasoutheast, DR) | DR is the paired region in the same country, for data residency. Others if needed: `se` (southeastasia), `ea` (eastasia), `myw` (malaysiawest). |
| `<nn>` | `01`, `02` | Instance number, only where more than one can exist. |

## HCP Terraform

| Object | Pattern | Example |
|---|---|---|
| Project | `<prefix>-<area>-<purpose>` | `lab-azure-platform`, `lab-entra-platform`, `lab-azure-workloads` |
| Workspace | `<prefix>-<area>-<level>-<component>-<env>` | `lab-azure-l0-org-prd`, `lab-entra-l1-ca-prd`, `lab-azure-l4-opsagent-np` |
| Variable set | `<prefix>-<area>-<purpose>` | `lab-azure-workload-credentials` |

Workspace names must match `^[a-z]{2,5}-(azure|entra|tfc)-l[0-4]-[a-z]+-(prd|np)$`. The `tfc/` root
fails the plan if one does not.

## Identities and GitHub

| Object | Pattern | Example |
|---|---|---|
| Pipeline app registration (platform level) | `<prefix>-<area>-<level>-plan` / `-apply` | `lab-azure-l0-plan`, `lab-azure-l0-apply` |
| Pipeline app registration (workload level) | `<prefix>-<area>-l4-plan` / `-apply` | `lab-azure-l4-apply` |
| GitHub environment | same as the identity it unlocks | `lab-entra-l1-apply` |
| Module release tag | `azure/<module>/<semver>` | `azure/private-endpoint/1.0.0` |
| Branch | `phase-<n>-<slug>`, `fix/<slug>`, or `evidence/<label>` | `phase-1-skeleton`, `evidence/2026-11-19-aiservices` |

The GitHub environment and the identity share a name on purpose: the federated credential subject
contains the environment name, so the mapping is visible at a glance.

## Azure resources

Pattern: `<prefix>-<type>-<component>-<env>-<region>[-<nn>]`, where `<type>` is the
[Cloud Adoption Framework abbreviation](https://learn.microsoft.com/azure/cloud-adoption-framework/ready/azure-best-practices/resource-abbreviations).

| Resource | Type | Example | Constraint |
|---|---|---|---|
| Management group | `mg` | `lab-mg-platform` | ID is fixed at creation; display name may change. |
| Resource group | `rg` | `lab-rg-connectivity-prd-ae` | |
| Virtual network | `vnet` | `lab-vnet-hub-prd-ae` | |
| Subnet | `snet` | `lab-snet-privateendpoints-prd-ae` | Azure-reserved names (`AzureFirewallSubnet`, `GatewaySubnet`, `AzureBastionSubnet`, `RouteServerSubnet`) are used as-is. |
| Log Analytics workspace | `log` | `lab-log-management-prd-ae` | |
| Key Vault | `kv` | `lab-kv-aiservices-prd-ae` | 3-24 characters, globally unique. |
| Storage account | `st` | `labstaiservicesprdae01` | 3-24 lowercase letters and digits, no hyphens, globally unique. |
| Policy definition / initiative | `pol` / `ini` | `lab-ini-baseline-v1` | Version suffix is part of the name (see the policy baseline). |
| Custom role | n/a | `lab-role-landingzone-owner` | |

## Entra ID

| Object | Pattern | Example |
|---|---|---|
| Persona group | `<prefix>-grp-persona-<persona>` | `lab-grp-persona-admins` |
| Conditional Access exclusion group | `<prefix>-grp-excl-<policy id>` | `lab-grp-excl-ca001` |
| Role-assignable group | `<prefix>-grp-role-<role>` | `lab-grp-role-securityreader` |
| Administrative unit | `<prefix>-au-<scope>` | `lab-au-privileged` |
| Conditional Access policy | `CA<nnn>-<Persona>-<Purpose>` | `CA001-Global-BlockLegacyAuth` |
| Named location | `<prefix>-nl-<name>` | `lab-nl-trusted-countries` |
| Authentication strength | `<prefix>-authstrength-<name>` | `lab-authstrength-phishingresistant` |

Conditional Access policy names use title case because people read them in sign-in logs. Personas
follow Microsoft's Zero Trust persona model: `Global`, `Admins`, `Internals`, `Guests`,
`WorkloadIdentities`.

Break-glass accounts are created by hand and are not covered by this convention
(see `entra/break-glass/`).

## Tags (Azure)

| Key | Example | Purpose |
|---|---|---|
| `managed-by` | `terraform` | Spot click-ops at a glance. |
| `workspace` | `lab-azure-l2-connectivity-prd` | Find the code that owns a resource. |
| `env` | `prd` | Cost and policy scoping. |
| `owner` | `platform` | A team, never a person. |
| `data-classification` | `internal` | Drives policy (for example, private endpoints only). |

## Tenant-specific values

Tenant IDs, subscription IDs and HCP organisation names never appear in code. Each root module reads
them from a variable file named after the tenant, which is git-ignored:

```text
<root>/env/<tenant>.auto.tfvars    # git-ignored, used on your machine
<root>/env/example.auto.tfvars     # committed, shows the shape
```

In CI the same variables come from GitHub environment variables (`TF_VAR_*`).
