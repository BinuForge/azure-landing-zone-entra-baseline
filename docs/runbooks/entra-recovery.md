# Entra recovery

What to do when tenant configuration is changed or deleted outside code. The code is the backup: every
setting this repository manages can be put back by applying its level again. This page covers the cases
where that is not enough on its own.

Start every recovery the same way: find out what changed (the nightly drift issue, or the audit log),
then plan the affected level and read the plan before approving anything.

## By what was lost

| What | Recover with | Time | Watch out for |
|---|---|---|---|
| A Conditional Access policy changed or deleted | Run `entra-l1-ca` (Actions, Run workflow). The plan recreates or reverts it | Minutes | A recreated policy starts report-only unless it is in `local.enforced` |
| A tenant default changed (consent, guests, authentication methods, cross-tenant) | Run `entra-l1-governance` | Minutes | These are singletons: nothing is deleted, only changed back |
| A persona group deleted | Restore it from deleted groups within 30 days (Entra admin centre, Groups, Deleted groups), keeping its ID. Otherwise run `entra-l0-org`, then `entra-l1-ca`, which picks up the new ID | Minutes | Restoring keeps every policy that references the group working |
| The break-glass exclusion group deleted | Restore it from deleted groups first, so its ID and the policies that exclude it stay valid. Then apply `level-0-privileged` locally to put it back in the unit | Minutes, but urgent | Until it is back, Conditional Access has no working exclusion: do not enforce any policy |
| The restricted administrative unit deleted | Apply `level-0-privileged` locally; it is recreated and its members added | Minutes | `prevent_destroy` stops Terraform deleting it, not a person in the portal |
| A break-glass account disabled, deleted or out of Global Administrator | Follow `entra/break-glass/README.md`; the privileged plan fails until it is fixed | Depends on the cause | Never weaken the plan checks to get past it |
| PIM eligibility or activation rules changed | Run `pim/Set-Pim.ps1 -Plan`, then `./Set-Pim.ps1` | Minutes | The CI plan's checks say what differs |
| A pipeline identity or Graph grant removed | Run the Entra bootstrap (`docs/runbooks/bootstrap.md`) | Minutes | Then re-run `set-pipeline-secrets.sh` if environments were recreated |
| HCP Terraform state lost | ADR-0003: restore from the Azure Storage fallback, or import | Hours | Plan before any apply; an empty state plans to create everything again |
| Every admin locked out | Sign in with a break-glass account; every policy excludes them | Minutes | Record the use (`entra/break-glass/README.md`) |

## After any recovery

1. Plan every Entra level and confirm `No changes`.
2. Read the audit log for who made the change, and why.
3. Record it: an issue, or a finding in `evidence/` if it was found by a test.
4. If the change was right, make it in code instead of reverting it.

## What is not recoverable from code

Users' authentication methods (passkeys, Authenticator), sign-in logs older than the workspace's
retention, and anything made by hand that was never in code. At bank scale, a scheduled export of tenant
configuration (for example Microsoft365DSC or the Entra exporter) covers the settings this repository
does not manage.
