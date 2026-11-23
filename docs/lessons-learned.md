# Lessons learned

Problems found while building and running the lab, with the cause and the fix. Most are general to
Terraform with Microsoft Graph and Azure, not specific to this repository.

## Terraform and providers

| Symptom | Cause | Fix | Lesson |
|---|---|---|---|
| The privileged plan wanted to remove the break-glass exclusion group from its restricted unit (#61) | Two providers managed one relationship: msgraph added the group to the unit, and azuread read `administrative_unit_ids` back as drift | `ignore_changes = [administrative_unit_ids]` on the group | When two resources manage one relationship, make exactly one the owner and tell the other to ignore it. Re-plan straight after the first apply to catch it |
| Every governance plan showed the consent reviewer changing (#63) | Graph stores `/groups/<id>/transitiveMembers` as `/v1.0/groups/<id>/transitiveMembers/microsoft.graph.user` | Write the value in the form Graph stores | APIs normalise values. A plan that is never empty after an apply usually means this |
| The first FIDO2 apply reported success, but the tenant was unchanged (#60, #62) | Graph accepted the update and did not apply it; the second identical apply took | A re-plan after apply, which showed the difference | "Apply complete" is the provider's view. The next plan is the proof |
| A saved plan named the wrong owner for new groups (#55) | The owner came from the signed-in identity, which at plan time is the plan identity | Pass the apply identity's object ID as a secret, `TF_VAR_apply_object_id` | A saved plan freezes every value at plan time, including who is signed in |
| Hierarchy settings failed to update in place (#53) | Azure returns a short name and expects a full ID on write | Read the settings in a `check`, replace when needed | Some resources cannot round-trip; check rather than manage them |
| Tests failed on unknown or random values from mocked resources | Mock providers return random strings and unknown computed attributes | `override_data` and `override_resource` with real-looking values; assert on inputs, not computed outputs | Mocks prove logic, not the provider |
| The final teardown failed on APIM's API, named value and diagnostic (destroy run 45276137887) | Terraform detached the NSG from the APIM subnet first. APIM's Standard public IP blocks all inbound traffic without an NSG, so Azure could not reach the management endpoint on 3443 | Delete the APIM service itself, which takes its children with it, then destroy again; APIM now depends on the NSG attachment | Destroy runs in reverse dependency order, so every network path a resource needs to be deleted must be a declared dependency, not just the rules |
| `terraform test` failed on a check that only warns in a plan | Tests treat a failed `check` as a failure | Give tests a healthy state, and add one test per check with `expect_failures` | This makes the tests prove the check fires, which is better |

## Identity and Graph

| Symptom | Cause | Fix | Lesson |
|---|---|---|---|
| Every PIM call from Terraform returned `PermissionScopeNotGranted` (#61) | The Azure CLI token carries `Directory.AccessAsUser.All` but no role management scopes, and first-party scopes cannot be added | A PowerShell script with a delegated Graph token for PIM, and Terraform checks on every plan (ADR-0019) | Decide the authentication path before the resource. Not everything that has an API can be applied by your provider's credentials |
| Removing the maintainer's standing Global Administrator failed with `AdminCannotRemoveSelf` | PIM does not let an admin remove their own assignment | Another admin removes it; here, a break-glass account | Plan the last step of a privilege reduction before the first |
| Groups created by a pipeline could not be changed by it | `Group.Create` lets an app manage only groups it owns | Name the apply identity as owner at creation | Least privilege has consequences for ownership; design for them |
| A group in a restricted unit could no longer have its members changed, even by Global Administrator | That is the purpose of a restricted management unit | Create the group with its members first, then add it to the unit | Order matters when a protection is fixed at creation |

## Pipelines and process

| Symptom | Cause | Fix | Lesson |
|---|---|---|---|
| A person-run plan showed "No changes" after a merge | The local checkout of `main` was stale | Every runbook starts with `git pull` and `git log --oneline -1` | Person-run roots need the discipline a pipeline gets for free |
| Identifiers appeared in public workflow logs | GitHub prints environment variable values; only secrets are masked | Tenant and subscription IDs are environment secrets (ADR-0012) | On a public repository, treat identifiers as secrets |
| A local scan passed but CI failed | A different checkov version ran different checks | Run the version pinned in `pr.yml`, in a virtual environment | Pin the scanner as you pin the provider |
| The AI threat model listed drift detection, but no drift workflow existed | A control was written before it was built | `drift.yml`, nightly | Every control in a threat model needs a pointer to its implementation, checked at review |
