# Emergency access (break-glass) accounts

Two accounts that can still sign in and hold Global Administrator when everything else has failed:
Conditional Access locks every admin out, MFA for daily admins is down, federation breaks, or a pipeline
identity is compromised.

## Why they are created by hand

Everything else in this repository is Terraform. These accounts are not, on purpose.

- If the pipeline identities or the Terraform state are compromised, an attacker who controls the code
  path must not also control the way back in.
- A `terraform destroy` or a bad plan must never be able to delete or change them.
- Their passwords must never pass through state, CI logs or variables.

Terraform only reads them, by object ID, to exclude them from Conditional Access and to check they are
still in the expected state.

## The accounts

| Property | Value | Why |
|---|---|---|
| Count | 2 | One can fail or be lost without losing emergency access |
| Names | `lab-emergency-01`, `lab-emergency-02` | Naming convention; no person's name |
| Domain | The tenant's initial `onmicrosoft.com` domain | No dependency on a custom domain, DNS or federation |
| Type | Cloud-only member accounts | No dependency on on-premises sync |
| Role | Global Administrator, permanent and active | PIM may be the thing that is broken, so the role is not eligible-only |
| Licence | None | Not needed for the role |
| Authentication | Now: Microsoft Authenticator (SMS and voice are off tenant-wide since ADR-0018). Target: one FIDO2 security key per account, stored apart (see open items) | MFA is mandatory for admin portals; a key cannot be phished |
| Password | 32 random characters, on paper only, each stored in a different place | Not in a password manager on a daily device |

The domain and object IDs are not committed. The names follow the convention and are public here:
`entra/level-0-privileged` finds the accounts by alias, so CI needs no identifiers. Their protection is
the restricted unit, the checks, phishing-resistant keys and the sign-in alert, not a hidden name.

## How the code uses them

| Where | What | Phase |
|---|---|---|
| Entra level 0 (`privileged`) | Both accounts and an exclusion group containing them, in a restricted management administrative unit, so no administrator or pipeline can change them without first taking an audited role on the unit (ADR-0016) | Entra baseline |
| Entra level 1 (`ca`) | Every Conditional Access policy excludes that group | Entra baseline |
| Checks (`entra/level-0-privileged`) | Exactly two accounts with the alias exist, are enabled, are cloud-only members and hold Global Administrator; the plan fails otherwise, in CI and locally | Entra baseline |
| Bootstrap | Entra sign-in logs to the security workspace (`entra_diagnostics`), then an alert on any sign-in by either account | Logs with the Entra baseline; the alert after it |

Sending sign-in logs to Log Analytics needs Entra ID P1 or P2. Without a licence, sign-ins are reviewed
in the Entra admin centre instead.

## Testing

| When | Test |
|---|---|
| After creation | Done 14 November 2026: both accounts signed in and reached the Entra admin centre |
| Every three months | Sign in with each account, confirm Global Administrator, sign out, record the date |
| After any Conditional Access change | Sign in with one account to prove the exclusion still works |

Record each test in `evidence/` with the date and result only, never a name or ID.

## If an account is used

1. Use it only for the emergency, then sign out.
2. Record why it was used and what changed.
3. Review its sign-in and audit logs.
4. Change its password, and re-register the key if it may have been exposed.

## Open items

- No FIDO2 security keys are registered yet. Both accounts use Microsoft Authenticator; SMS and voice
  have been off tenant-wide since 2026-11-22 (ADR-0018). Authenticator depends on a phone, so this is
  weaker than Microsoft's guidance. It is an accepted gap for the lab, closed before any Conditional
  Access policy is switched from report-only to on: register a key for each account.
- The account that signed up for the Azure free account is a guest with Global Administrator. It is
  probably also the billing owner, so it is not deleted. Before the Entra baseline: confirm the daily
  admin has Owner on the subscription, then remove Global Administrator from the guest and keep it for
  billing only.
