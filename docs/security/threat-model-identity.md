# Threat model: identity

- **Scope:** the Entra ID tenant, its pipeline identities, and the Entra levels (`entra/`)
- **Date:** 2026-11-22
- **Method:** STRIDE per threat, mapped to controls in code, the test or check that proves each one, and
  the risk that remains

Identity is the larger attack surface: a stolen admin session reaches everything the AI threat model
protects, and more. This model sits beside [the AI threat model](threat-model-ai.md).

## 1. What is being modelled

| Component | What it is |
|---|---|
| Pipeline identities | Plan and apply app registrations per workspace, federated to GitHub environments (ADR-0012, ADR-0016) |
| Person-run roots | `bootstrap/`, `entra/bootstrap/`, `entra/level-0-privileged`, `pim/Set-Pim.ps1` |
| Break-glass | Two cloud-only Global Administrators, excluded from Conditional Access, in a restricted administrative unit |
| Daily admin | The maintainer, eligible for privileged roles through PIM |
| Users and guests | Internals and guests persona groups |
| Tenant policy | Conditional Access, authorisation policy, authentication methods, cross-tenant defaults, consent |

Trust boundaries: GitHub to Entra (OIDC token exchange), the maintainer's machine to Entra (delegated
tokens), the internet to Entra sign-in, and other tenants to this one (B2B).

## 2. Assets

| Asset | Why it matters |
|---|---|
| Global Administrator and Privileged Role Administrator | Either can grant any role, including itself |
| Graph permissions that grant permissions | `AppRoleAssignment.ReadWrite.All`, `RoleManagement.ReadWrite.Directory`, `Application.ReadWrite.All` |
| The break-glass exclusion group | Membership escapes every Conditional Access policy |
| Conditional Access policies | Weakening one silently lowers protection for everyone |
| Sign-in and audit logs | Evidence of misuse, and personal data |

## 3. Who might attack it

| Actor | Starting point |
|---|---|
| External phisher | A user's or admin's mailbox and browser |
| Supply chain attacker | A compromised GitHub account, workflow or action |
| Malicious or careless insider | A legitimate account with some rights |
| Partner tenant compromise | A guest account or a cross-tenant trust |

## 4. Threats

| ID | Threat | STRIDE | Controls | Proof | Remaining risk |
|---|---|---|---|---|---|
| IT-01 | Admin credentials phished | Spoofing | CA004 phishing-resistant MFA for 14 roles; passkeys device-bound; SMS and voice off; PIM 4 h activation | `tests/ca.tftest.hcl`, `tests/governance.tftest.hcl`, `pim.tf` checks | CA004 is report-only until ADR-0017's bar is met |
| IT-02 | Session token stolen by an adversary-in-the-middle proxy | Spoofing | Phishing-resistant MFA defeats the proxy at sign-in; risky sign-in policy CA007 | `tests/ca.tftest.hcl` | No token protection or device compliance (bank-scale target) |
| IT-03 | Illicit consent grant: a user approves a malicious app | Elevation of privilege | Users consent to nothing; admin consent requests go to a PIM-eligible group | `tests/governance.tftest.hcl` | An admin can still approve a bad request |
| IT-04 | A user registers an app and abuses it | Elevation of privilege | `allowedToCreateApps = false` | `tests/governance.tftest.hcl` | None material |
| IT-05 | A GitHub compromise runs a pipeline as an apply identity | Elevation of privilege | Environment approvals, branch policies, one level per identity, OIDC subject pinned to repository IDs | `bootstrap` and `entra/bootstrap` tests, ADR-0006 | One maintainer approves (ADR-0006) |
| IT-06 | A pipeline grants itself more permissions | Elevation of privilege | No pipeline holds any Tier 0 Graph permission; the allowed list is by ID | `tests/graph.tftest.hcl` deny list | None material |
| IT-07 | Someone excludes themselves from Conditional Access | Tampering | Every policy excludes only the break-glass group; the group is in a restricted unit | `tests/ca.tftest.hcl`, `tests/privileged.tftest.hcl` | A Global Administrator can remove the group from the unit; audited, not alerted |
| IT-08 | A break-glass account is used by an attacker | Spoofing | Long random passwords stored offline, restricted unit, plan checks | `breakglass.tf` preconditions | No sign-in alert yet; no FIDO2 keys yet |
| IT-09 | Break-glass silently stops working (disabled, synced, loses Global Administrator, a look-alike added) | Denial of service | Five preconditions fail every plan | `tests/privileged.tftest.hcl` | Detected at the next plan, or the nightly drift run |
| IT-10 | Standing privileged access is abused | Elevation of privilege | PIM eligibility for every admin role; check that only break-glass holds standing Global Administrator | `pim.tf` check, `tests/pim.tftest.hcl` | The maintainer still holds standing Global Administrator (ADR-0019, accepted) |
| IT-11 | A guest maps the directory or invites others | Information disclosure | Restricted Guest User; only admins and Guest Inviters invite | `tests/governance.tftest.hcl` | None material |
| IT-12 | A compromised partner tenant's MFA claim is trusted | Spoofing | No inbound MFA or device trust; direct connect blocked | `tests/governance.tftest.hcl` | None material |
| IT-13 | Password spray through legacy protocols | Spoofing | CA001 blocks legacy authentication; CA007 and CA008 on risk | `tests/ca.tftest.hcl` | Report-only until enforced |
| IT-14 | Device code phishing | Spoofing | CA002 blocks device code flow and authentication transfer | `tests/ca.tftest.hcl` | Report-only until enforced |
| IT-15 | Policy changed in the portal, outside code | Tampering | Nightly drift plan opens an issue; PIM checks warn | `drift.yml` | Up to a day before it is noticed |
| IT-16 | Logs disabled to hide activity | Repudiation | Entra diagnostics in bootstrap, a person-run root; logs in a workspace pipelines cannot read | `bootstrap/tests/security_logs.tftest.hcl` | A Global Administrator can disable diagnostics; no alert |
| IT-17 | The Graph PowerShell grant used by the PIM script is abused | Elevation of privilege | Consent for the maintainer only, never for the organisation; scopes need an active role to matter | ADR-0019 | The grant persists until revoked |
| IT-18 | The person-run roots are run from a stale or tampered checkout | Tampering | Runbooks start with `git log --oneline -1` on an up-to-date `main`; CI plans the same code first | runbooks | Relies on the maintainer following the runbook |

## 5. What a bank would add

- Sentinel analytics rules for break-glass sign-in, any change to the exclusion group or restricted unit,
  PIM activation of Tier 0 roles, Conditional Access changes and diagnostic setting changes.
- A second approver for Tier 0 activation and for every apply environment.
- Token protection, device compliance and continuous access evaluation for admins.
- Quarterly access reviews of eligible assignments, guests and app permissions.
- Workload identity Conditional Access for pipeline identities (Workload ID Premium).
- Regular attack simulation and an identity incident response playbook, exercised.

## 6. Review

Review this model when an Entra level changes, when a new identity is added, or every six months.
