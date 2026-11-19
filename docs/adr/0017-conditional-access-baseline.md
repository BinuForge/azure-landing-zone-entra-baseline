# ADR-0017: Conditional Access baseline starts report-only and excludes one protected group

- **Status:** Accepted
- **Date:** 2026-11-19

## Context

- `entra/level-1-ca` holds the tenant's Conditional Access policies. Its apply identity holds
  `Policy.Read.All` and `Policy.ReadWrite.ConditionalAccess` only (ADR-0016).
- A wrong policy can lock every administrator out of the tenant. Microsoft's guidance is to exclude
  emergency access accounts from every policy and to try each policy in
  [report-only mode](https://learn.microsoft.com/en-us/entra/identity/conditional-access/concept-conditional-access-report-only)
  first. Report-only evaluates every sign-in and records the result without blocking anyone.
- The break-glass exclusion group `lab-grp-excl-breakglass` sits in the restricted management
  administrative unit `lab-au-emergency` (ADR-0016, decision 5). Nobody can change its members without
  first taking a role on the unit, which is audited.
- Personas follow Microsoft's Zero Trust model (`docs/naming.md`). Level 0 has internals and guests groups
  with dynamic membership. Administrators are not a group.
- The tenant runs a 30-day Entra ID P2 trial. Sign-in and user risk conditions need P2; everything else
  needs P1.
- Security defaults and Conditional Access cannot both enforce. Report-only policies can be created while
  security defaults are on.
- Workload identities are out of scope: Conditional Access for them needs Workload ID Premium.

## Options considered

### Starting state

| Option | For | Against |
|---|---|---|
| Report-only, enforced one policy at a time | No lockout; evidence before each change | No protection until each is enforced |
| Enforced at once | Protection on day one | One mistake locks out every administrator, and the lab's only path back is break-glass |

### Targeting administrators

| Option | For | Against |
|---|---|---|
| By directory role | Covers anyone who holds or activates a role, including through PIM | Long list of role IDs to keep current |
| By an admins group | One ID | Misses a role assigned directly or activated through PIM outside the group |

### Exclusions

| Option | For | Against |
|---|---|---|
| One group in the restricted unit, excluded from every policy | One audited place to opt out | Every exclusion is all or nothing |
| One exclusion group per policy | Fine-grained, the usual bank pattern | Each group needs protecting and reviewing |
| Excluded users or roles in the policy | Simple | Anyone with `Policy.ReadWrite.ConditionalAccess` can opt themselves out unseen |

### Guests

| Option | For | Against |
|---|---|---|
| The guest and external user condition | Covers every external type, including external users whose type is Member | Not reusable outside Conditional Access |
| The guests persona group | One model for every persona | Misses external members and direct connect users |

### Policy definitions

| Option | For | Against |
|---|---|---|
| Data map with one resource | Every policy gets the same exclusion and checks; a new policy is a reviewed entry | A little indirection |
| One resource per policy | Reads like the portal | Each policy can drift from the shared rules |

## Decision

1. Eight policies, all created report-only:

   | Policy | Who | Control |
   |---|---|---|
   | `CA001-Global-BlockLegacyAuth` | All users, legacy clients | Block |
   | `CA002-Global-BlockDeviceCodeFlow` | All users, device code and authentication transfer | Block |
   | `CA003-Global-BlockUntrustedCountries` | All users outside `lab-nl-trusted-countries` (Australia; unknown countries not trusted) | Block |
   | `CA004-Admins-RequirePhishingResistantMfa` | Microsoft's 14 privileged directory roles | Built-in phishing-resistant MFA strength |
   | `CA005-Internals-RequireMfa` | Internals persona group | MFA |
   | `CA006-Guests-RequireMfa` | Every guest and external user type | MFA |
   | `CA007-Global-RiskySignInRequireMfa` | All users, medium or high sign-in risk | MFA, sign-in every time |
   | `CA008-Global-HighUserRiskRequirePasswordChange` | All users, high user risk | MFA and a password change, sign-in every time |

2. Every policy excludes `lab-grp-excl-breakglass` and nothing else. No policy excludes a user or a role.
   Tests enforce this, and the plan stops if level 0 privileged has not published the group.
3. Administrators are targeted by role template ID, checked against `GET /directoryRoleTemplates`.
4. Policies are entries in `local.policy_specs` (`policies.tf`), applied by one resource.
5. A policy is enforced by adding its ID to `local.enforced`, in its own pull request, once it meets the
   bar below. The test that expects report-only changes in the same pull request.

### Bar for enforcing a policy

- At least seven days of report-only results, read in the sign-in logs or the Conditional Access insights
  workbook (`docs/runbooks/entra-conditional-access.md`).
- No `reportOnlyFailure` for a legitimate sign-in, and a known reason for every `reportOnlyInterrupted`.
- Break-glass sign-ins show the policy as not applied.
- For CA004, every holder of a listed role has registered a passkey or FIDO2 key.
- Security defaults are off before the first policy is enforced, and only once CA001, CA005 and CA006 are
  ready to replace them.

Suggested order: CA001 and CA002, then CA005 and CA006 with security defaults off, then CA004, CA003,
CA007 and CA008. If security defaults are already off, CA005 and CA004 come first.

## Risks accepted

| Risk | Why it is accepted | Mitigation, or how we would notice |
|---|---|---|
| Report-only policies protect nothing | Lockout is worse in a one-maintainer tenant | If security defaults are on, they stay on until policies replace them; if not, CA005 and CA004 are enforced first |
| The apply identity can weaken or disable any policy | It needs `Policy.ReadWrite.ConditionalAccess` to manage them | Apply needs approval in `lab-entra-l1-ca-apply`; tests pin the exclusion and the state; it cannot change the exclusion group's members |
| CA007 and CA008 stop evaluating risk when the P2 trial ends | Trial licence | They fail open with no error. The Entra levels are torn down or licensed before the trial ends (`docs/cost.md`) |
| CA003 blocks travel and VPN sign-ins | Expected for a home-region lab | Report-only first; break-glass is excluded |
| The country list is IP-based | GPS lookup needs Authenticator prompts on every sign-in | Accepted for a lab |

## Consequences

- Easier: every policy shares one exclusion and one set of tests, and the plan shows exactly which policy
  changes state.
- Harder: enforcing is deliberate work, one pull request per policy.
- At bank scale this grows to Microsoft's full persona framework, with per-policy exclusion groups under
  quarterly access reviews, a custom authentication strength limited to approved FIDO2 models by AAGUID,
  device compliance through Intune, token protection, workload identity policies, what-if tests in the
  pipeline (Maester), separate approvers for Conditional Access changes, and a SIEM alert on any policy
  change or any sign-in by a break-glass account.
