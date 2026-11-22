# Control mapping

What each control in this repository does, where it is in code, how it is tested, and which framework
areas it supports.

This is not a compliance assessment. It says the design supports a control area, never that it
complies, and it claims no Essential Eight maturity level. Framework references are at the level of an
Essential Eight strategy, a Microsoft cloud security benchmark (MCSB v1) control, an ISM guideline and an
APRA CPS 234 theme. Individual ISM control numbers are not mapped.

## Identity and access

| Control | Where | Tested by | Essential Eight | MCSB | ISM guideline | CPS 234 theme |
|---|---|---|---|---|---|---|
| Pipelines authenticate with OIDC federation; no client secret exists | `modules/github-pipeline-identity`, `bootstrap/identities.tf` | module tests; evidence shows federated credentials only | Restrict administrative privileges | IM-3, IM-8 | System hardening (authentication hardening) | Implementation of controls |
| Read-only plan identity and single-level apply identity per workspace | `bootstrap/rbac.yaml`, `entra/bootstrap/graph.yaml` | `bootstrap` and `entra/bootstrap` tests | Restrict administrative privileges | PA-7 | System management (system administration) | Implementation of controls |
| No pipeline holds a Tier 0 Graph permission | `entra/bootstrap/graph.tf` | `tests/graph.tftest.hcl` deny list | Restrict administrative privileges | PA-1 | System management | Implementation of controls |
| Standing Global Administrator for break-glass only; everyone else eligible through PIM, 4 h activation with MFA and justification | `entra/level-0-privileged/pim/` | `pim.tf` checks on every plan; `tests/pim.tftest.hcl` | Restrict administrative privileges | PA-1, PA-2 | System management | Implementation of controls |
| Two cloud-only break-glass accounts, checked on every plan, in a restricted administrative unit | `entra/level-0-privileged/breakglass.tf`, `restricted.tf` | `tests/privileged.tftest.hcl` | Restrict administrative privileges | PA-5 | System management | Incident management |
| Phishing-resistant MFA for 14 privileged roles | `entra/level-1-ca` CA004 | `tests/ca.tftest.hcl` | Multi-factor authentication | IM-6, IM-7 | System hardening (authentication hardening) | Implementation of controls |
| MFA for internals and every external user type; legacy authentication and device code flow blocked | CA001, CA002, CA005, CA006 | `tests/ca.tftest.hcl` | Multi-factor authentication | IM-6, IM-7 | System hardening | Implementation of controls |
| Risk-based sign-in and user policies | CA007, CA008 | `tests/ca.tftest.hcl` | Multi-factor authentication | IM-7, LT-1 | System monitoring | Incident management |
| SMS and voice off; passkeys device-bound with attestation | `entra/level-1-governance/authentication_methods.tf` | `tests/governance.tftest.hcl` | Multi-factor authentication | IM-6 | System hardening (authentication hardening) | Implementation of controls |
| Users consent to nothing; admin consent requests reviewed by a PIM-eligible group | `authorization.tf`, `consent.tf` | `tests/governance.tftest.hcl` | User application hardening (supporting) | IM-3, PA-7 | System hardening | Implementation of controls |
| Restricted guest role, admin-only invitations, no inbound cross-tenant trust | `authorization.tf`, `cross_tenant.tf` | `tests/governance.tftest.hcl` | Restrict administrative privileges (supporting) | IM-1, IM-7 | Personnel security (access to systems) | Implementation of controls |

## Platform and network

| Control | Where | Tested by | Essential Eight | MCSB | ISM guideline | CPS 234 theme |
|---|---|---|---|---|---|---|
| Azure landing zone management group hierarchy; policy assigned at the root | `azure/level-0-org`, `azure/level-1-governance` | level tests; evidence `management-groups.json` | - | GS-2, AM-2 | System management | Policy framework |
| No public IP addresses in corp | `assignments.tf` (`corp-no-pip`) | `tests/policy/` deny cases | - | NS-1, NS-2 | Networking (network design and configuration) | Implementation of controls |
| AI services: no keys, no public network, approved models and guardrail only | `initiatives.tf` | `tests/policy/`, `tests/gateway/` | Application control (supporting) | NS-2, AM-2, IM-1 | Networking; Software development | Implementation of controls |
| Microsoft cloud security benchmark assigned in audit mode | `assignments.tf` (`mcsb`) | evidence `policy-assignments.json` | - | All, as a baseline | - | Testing control effectiveness |
| Hub and spoke network, private endpoints, private DNS | `azure/level-2-platform`, `azure/level-3-aiservices/network.tf` | level tests; `docs/architecture/address-plan.md` | - | NS-1, NS-2 | Networking | Implementation of controls |
| AI gateway enforces caller identity, token limits and a kill switch | `azure/level-3-aiservices/apim.tf` | `tests/gateway/` (GW cases) | - | IM-1, PA-7 | Software development | Implementation of controls |
| Encryption keys follow data classification | ADR-0014 | `azure/level-3-aiservices/tests` | - | DP-4, DP-5 | Cryptography | Information asset identification and classification |

## Logging, monitoring and response

| Control | Where | Tested by | Essential Eight | MCSB | ISM guideline | CPS 234 theme |
|---|---|---|---|---|---|---|
| Entra sign-in and audit logs to a security workspace only the maintainer reads | `bootstrap/security_logs.tf` | `bootstrap/tests/security_logs.tftest.hcl` | - | LT-1, LT-3, LT-5 | System monitoring (event logging and monitoring) | Incident management |
| Prompt content in a separate workspace, every query against it alerts | `azure/level-3-aiservices/logging.tf` | `tests/agent/access.sh` (T-10a) | - | LT-3, DP-2 | System monitoring | Information asset identification and classification |
| Nightly drift plan of every persistent level, issue on drift | `.github/workflows/drift.yml` | the workflow itself | - | GS-7, LT-1 | System monitoring | Testing control effectiveness |
| Break-glass and recovery runbooks | `entra/break-glass/`, `docs/runbooks/entra-recovery.md` | - | Regular backups (supporting: configuration as code) | PA-5, BR-1 | Cyber security incidents | Incident management |

## Delivery and supply chain

| Control | Where | Tested by | Essential Eight | MCSB | ISM guideline | CPS 234 theme |
|---|---|---|---|---|---|---|
| Threat model before the AI build; every control has a test | `docs/security/threat-model-ai.md`, `threat-model-identity.md` | `tests/` live tests | - | DS-1 | Software development | Information security capability |
| Providers, tools and actions pinned; actions by commit SHA; Dependabot | ADR-0001, `.github/dependabot.yml` | `pr.yml` | Patch applications (supporting) | DS-2 | Software development | Implementation of controls |
| PR gates: fmt, validate, tflint, checkov, gitleaks, terraform test | `.github/workflows/pr.yml`, `.pre-commit-config.yaml` | every pull request | - | DS-3, DS-4 | Software development | Testing control effectiveness |
| Saved, encrypted plans applied only after a person approves | `_plan.yml`, `_apply.yml`, ADR-0006 | workflow runs | Restrict administrative privileges (supporting) | DS-3, PA-7 | System management (change management) | Implementation of controls |
| Signed evidence from live deployments | `evidence/`, ADR-0011 | `evidence.yml` attests every file in the Sigstore transparency log | - | GS-7 | System monitoring | Testing control effectiveness; Internal audit |
| OpenSSF Scorecard on the repository | `.github/workflows/scorecard.yml` | the workflow itself | - | DS-2 | Software development | Testing control effectiveness |

## Known gaps

| Gap | Framework area | Where it is tracked |
|---|---|---|
| Conditional Access is report-only until each policy meets ADR-0017's bar | Multi-factor authentication | ADR-0017 |
| The maintainer still holds standing Global Administrator | Restrict administrative privileges, PA-2 | ADR-0019 risks |
| No SIEM alert on break-glass sign-in, PIM activation or policy change | LT-1, Incident management | Identity threat model |
| No access reviews of eligible assignments | PA-4 | ADR-0019, bank-scale target |
| No device compliance or token protection | IM-7 | ADR-0017, bank-scale target |
| Patch, macro and application control strategies are endpoint controls, out of scope for this repository | Essential Eight | - |
