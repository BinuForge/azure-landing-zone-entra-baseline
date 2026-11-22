# ADR-0019: PIM is applied by a person with a delegated token and checked by Terraform

- **Status:** Accepted
- **Date:** 2026-11-22

## Context

- The maintainer's daily admin holds Global Administrator permanently. Microsoft's guidance is that only
  emergency access accounts hold standing Global Administrator; everyone else is eligible through
  Privileged Identity Management (PIM) and activates for a limited time.
- PIM's APIs need delegated scopes such as `RoleManagement.ReadWrite.Directory` and
  `RoleManagementPolicy.ReadWrite.Directory`. Checked on 2026-11-22: the Azure CLI's Graph token, which
  the azuread and msgraph providers use on the maintainer's machine, carries `Directory.AccessAsUser.All`
  and none of the role management scopes, and first-party preauthorisation cannot be extended. Every PIM
  call returned `PermissionScopeNotGranted`.
- ADR-0016 gives no pipeline identity a Tier 0 permission, and the role management write permissions are
  Tier 0.
- `lab-entra-l0-privileged-plan` already holds the PIM read permissions.
- The admin consent request workflow (ADR-0018) needs reviewers who are not named people.

## Options considered

| Option | For | Against |
|---|---|---|
| Script with a delegated Graph token as the maintainer, desired state in `pim.json`, Terraform checks on every plan | No standing Tier 0 permission anywhere; one reviewed file; drift is flagged | Two tools: a script applies, Terraform verifies |
| Pipeline identity with `RoleManagement.ReadWrite.Directory` | All in Terraform | A GitHub compromise becomes Global Administrator (rejected in ADR-0016) |
| An app with a secret or certificate, used only locally | All in Terraform | A long-lived credential that can make anyone Global Administrator |
| Portal by hand | Quick | No record, no review, no drift check |

## Decision

1. `entra/level-0-privileged/pim/pim.json` is the desired state: four roles, their maximum activation
   (Global Administrator and Privileged Role Administrator 4 hours, Security Administrator and Cloud
   Application Administrator 8 hours), MFA and a justification on activation, and eligible assignments
   that expire after 365 days.
2. `pim/Set-Pim.ps1` applies it with `Connect-MgGraph`, signed in as the maintainer, consenting for
   themselves only. `-Plan` prints changes without making them. `-RemoveStandingAccess` removes the
   maintainer's permanent assignments, only after checking they are eligible for Global Administrator and
   both break-glass accounts still hold it.
3. The maintainer is eligible for Global Administrator, Privileged Role Administrator and Security
   Administrator. `lab-grp-role-cloudappadmin`, a role-assignable group with the maintainer as member, is
   eligible for Cloud Application Administrator. Its members review admin consent requests.
4. `pim.tf` checks, on every CI plan: only the break-glass accounts hold standing Global Administrator,
   every role has an eligible principal, and each role's activation rules match `pim.json`. Checks warn
   rather than fail, so a local plan works without PIM read access. Tests prove each check fires.
5. Only the break-glass accounts keep standing Global Administrator. Tier 0 runs (bootstrap, Entra
   bootstrap, level 0 privileged) start with activating Global Administrator in PIM.

## Risks accepted

| Risk | Why it is accepted | Mitigation, or how we would notice |
|---|---|---|
| The Graph PowerShell app holds a delegated grant with PIM scopes for the maintainer | Needed to call PIM | Consent for self only; the grant works only while the maintainer is signed in and holds the role |
| No approver on activation | One maintainer | MFA and justification; activations are in the audit log |
| PIM state is not in Terraform state | The provider cannot authenticate for it | Checks on every plan; tests prove the checks fire |
| The maintainer's eligibility lapses after a year | Intended: renewal is a deliberate act | The eligibility check warns when it lapses |

## Consequences

- Easier: a stolen daily admin session is no longer a standing Global Administrator.
- Harder: every Tier 0 run starts with a PIM activation.
- At bank scale: PIM owned by the identity team, approval by a second person for Tier 0 roles, an
  authentication context on activation that requires phishing-resistant MFA, quarterly access reviews of
  every eligible assignment, PIM alerts in the SIEM, and role-assignable groups for every role so access is
  granted by membership.
