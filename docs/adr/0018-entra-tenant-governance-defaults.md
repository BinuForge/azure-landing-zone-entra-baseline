# ADR-0018: Tenant defaults deny by default, and passkeys replace phone methods

- **Status:** Accepted
- **Date:** 2026-11-19

## Context

- `entra/level-1-governance` holds tenant-wide settings: the authorisation policy, authentication methods
  and the default cross-tenant access policy. Its apply identity holds `Policy.Read.All` and the
  ReadWrite permissions for authorisation, authentication methods, cross-tenant access and consent
  requests (ADR-0016). azuread has no resources for these, so they are set with `msgraph_update_resource`.
- Read on 2026-11-19, the tenant still had sign-up defaults: anyone could invite guests, guests held Guest
  User, users could create apps, security groups and tenants, and users could consent to apps from
  verified publishers. Direct connect was already blocked and no other tenant's MFA was trusted.
- Illicit consent grants and app registrations by ordinary users are a common path to a tenant takeover.
  Microsoft recommends disabling user consent or limiting it, with an admin consent workflow.
- SMS and voice can be phished and SIM-swapped. Passkeys are phishing-resistant and are what CA004
  (ADR-0017) requires of administrators.
- Passkey profiles replace the FIDO2 `isAttestationEnforced` and `keyRestrictions` properties, which are
  deprecated and removed in October 2027. A tenant may not have profiles yet.
- These are singletons. Removing a `msgraph_update_resource` leaves the setting as it is.

## Options considered

### User consent

| Option | For | Against |
|---|---|---|
| None; admins decide every permission | Removes illicit consent as a path | Users wait for an admin |
| Verified publishers, low-risk permissions only (Microsoft's recommended setting) | Less friction | Still a consent path for any verified publisher, and "low risk" is Microsoft's list, not ours |
| Defaults | No change | Users consent to apps from any verified publisher |

### Guest access

| Option | For | Against |
|---|---|---|
| Restricted Guest User, invited by admins and Guest Inviters | Guests see only their own objects; inviting is a role | Teams and SharePoint owners cannot invite |
| Guest User | Guests can read group membership | Enough to map the directory |

### Phone methods

| Option | For | Against |
|---|---|---|
| Off, with passkeys, Authenticator and Temporary Access Pass on | Removes the phishable methods; a one-time pass bootstraps a passkey | Anyone with only SMS registered must register again |
| On as a fallback | No re-registration | Attackers pick the weakest method allowed |

## Decision

1. Users consent to nothing (`permissionGrantPoliciesAssigned` is empty) and create no apps, security
   groups or tenants. They request consent instead: the admin consent workflow sends requests to the
   members of `lab-grp-role-cloudappadmin`, a role-assignable group eligible for Cloud Application
   Administrator through PIM (ADR-0019), read from level 0 privileged. No person is named, and the
   workflow stays off until the group exists.
2. Guests hold Restricted Guest User. Only admins and Guest Inviters invite, and nobody joins through a
   verified email address or self-service sign-up.
3. Cross-tenant defaults are set explicitly, even where they match Microsoft's defaults, so drift shows in
   the plan: guest collaboration allowed, direct connect blocked both ways, no inbound trust, no automatic
   redemption.
4. Passkeys on for all users: device-bound only, with attestation at registration. On a tenant without
   passkey profiles, `isAttestationEnforced` instead. The body follows what the plan identity reads.
5. Microsoft Authenticator on without one-time codes. Temporary Access Pass on, one use, 1 to 8 hours.
   SMS and voice off.

## Risks accepted

| Risk | Why it is accepted | Mitigation, or how we would notice |
|---|---|---|
| An account with only SMS or voice registered must register again | The point of the change | Before applying, check the daily admin and both break-glass accounts have Authenticator or a passkey (`docs/runbooks/entra-governance.md`) |
| A reviewer can see and deny requests without activating a role | Reviewing alone grants nothing | Approving needs Cloud Application Administrator, or Global Administrator for application permissions, both through PIM |
| Synced passkeys (iCloud, Google) cannot be registered | They can be copied to devices the tenant never sees | Authenticator passkeys and security keys are device-bound |
| Removing a resource does not undo its setting | Singletons have no delete | Revert by applying the old value first, then removing the resource |
| The apply identity can weaken any of these settings | It needs the ReadWrite permissions to manage them | Apply needs approval in `lab-entra-l1-governance-apply`; tests pin every value |

## Consequences

- Easier: every tenant default is in code, tested, and shows as drift if changed in the portal.
- Harder: an app that needs user consent needs an admin, and phone-only users need a Temporary Access Pass.
- At bank scale: an approved app catalogue with admin consent through a ticketed workflow, AAGUID allow
  lists for security keys, cross-tenant partner policies per organisation with inbound MFA trust only
  where contracted, Tenant Restrictions v2 on corporate devices, and Entra ID Governance for guest
  lifecycle and access reviews.
