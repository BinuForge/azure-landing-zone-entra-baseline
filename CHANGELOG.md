# Changelog

Notable changes, newest first. Each entry links the pull requests. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## 2026-11-23: Deploy your own copy

- [QUICKSTART](QUICKSTART.md): deploy the lab into a new trial tenant and subscription, learn, then
  tear it down. A read-only preflight script checks tools, sign-ins, the trial, the tenant and name
  availability (ADR-0020).
- One `unique_suffix` (repository variable `LAB_UNIQUE_SUFFIX`) for the three names that must be unique
  across Azure. Empty for the original lab, so its plans do not change.
- The GitHub owner and apply reviewer are required inputs, not defaults; helper scripts take the
  repository from the clone.
- Docs for engineers: [how it works](docs/how-it-works.md) on one page, a [glossary](docs/glossary.md)
  and a [runbook index](docs/runbooks/README.md), linked from the top of the README.
- [Rebuild in a new tenant](docs/runbooks/rebuild-in-new-tenant.md): move this repository to a new tenant
  and subscription, deleting the old HCP workspaces through code so nothing stale is left. ADR-0004 stands.

## 2026-11-22: Entra baseline, part 2, and assurance

- Tenant defaults: users consent to nothing, restricted guests, admin-only invitations, explicit
  cross-tenant defaults, passkeys device-bound with attestation, SMS and voice off (#60, ADR-0018).
- PIM: eligible roles, 4-hour Tier 0 activation with MFA and justification, applied by a delegated script
  and checked on every plan (#61, ADR-0019).
- Admin consent requests reviewed by a PIM-eligible group (#62, #63).
- Fixed: the break-glass exclusion group would have been taken out of its restricted unit by the next
  apply (#61).
- Architecture overview, story, control mapping, identity threat model, landing zone comparison, ADR
  index, recovery runbook, lessons learned, nightly drift detection, OpenSSF Scorecard.

## 2026-11-19: Entra baseline, part 1

- Entra pipeline identities with least-privilege Graph permissions and a Tier 0 deny list (#54, #55,
  ADR-0016).
- Persona groups with dynamic membership (#56).
- Break-glass protection: restricted administrative unit, exclusion group, five plan checks (#57).
- Conditional Access baseline, CA001 to CA008, report-only (#58, ADR-0017).
- Entra sign-in and audit logs to a security workspace (#54).

## 2026-11-18: Ops agent

- Level 4: the ops agent's runner, read-only roles, canary and pipeline (#44 to #48).
- Live tests for the agent's controls, 18 cases (#50, #52).
- No pipeline identity reads log data unless that is its job (#43, ADR-0012).
- Pipeline role assignments as data in `rbac.yaml` (#51).

## 2026-11-15: Platform and AI services

- Level 1 policy baselines and policy deny tests (#16 to #21).
- Level 2: ops workspace, hub network, private DNS (#22 to #24).
- Level 3: AI services landing zone and the APIM AI gateway, with live gateway tests (#25 to #41).
- Evidence packs: baseline, policy, AI services, gateway retest.

## 2026-11-14: Bootstrap and level 0

- Bootstrap: budget, resource providers, resource groups, pipeline identities, RBAC, GitHub environments
  (#2 to #8, #10).
- Level 0 management groups and the first deploy pipeline (#9).
- Destroy workflow with a leftovers check (#11), and attested evidence collection (#12).
