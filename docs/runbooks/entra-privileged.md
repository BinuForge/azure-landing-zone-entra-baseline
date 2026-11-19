# Entra level 0, privileged (Tier 0)

`entra/level-0-privileged` holds objects that can make someone Global Administrator or let them skip
Conditional Access: the restricted management administrative unit `lab-au-emergency`, the break-glass
exclusion group, and later custom roles, role-assignable groups and PIM. CI plans it with a read-only
identity on every pull request and every merge. Only the maintainer applies it, from their own machine,
signed in as Global Administrator (ADR-0016, decision 1).

## Apply

Run from `entra/level-0-privileged/`, on an up-to-date `main`, after the change has merged and its CI plan
has been read. Check `git log --oneline -1` first: a stale checkout plans the wrong code.

```sh
export TF_CLOUD_ORGANIZATION=<org>
terraform init
terraform plan -out=tfplan
terraform apply tfplan
```

The plan fails if a break-glass account is missing, disabled, synced from on-premises, a guest, no longer
a Global Administrator, or if a third account uses the `lab-emergency-` alias. Fix the account, never the
check.

The first run needs no variables. On a new tenant, set the workspace `lab-entra-l0-privileged-prd` to
Local execution first, as for bootstrap.

## Changing a member of the restricted unit

Inside `lab-au-emergency`, nobody can change the break-glass accounts or the exclusion group, Global
Administrators included, until they hold a role scoped to the unit. To change one:

1. Entra admin centre, Roles and admins, Administrative units, `lab-au-emergency`, Roles and
   administrators. Assign yourself Groups Administrator (or User Administrator, for an account) on the
   unit only.
2. Make the change through Terraform as above.
3. Remove the role assignment. Steps 1 and 3 are recorded in the audit log.

A Global Administrator can also remove an object from the unit, which removes its protection. Doing so
is an incident unless a pull request explains it.

## If a break-glass account is used

Follow `entra/break-glass/README.md`. Resetting its password needs it out of the unit first, because no
role assignable to a unit can reset a Global Administrator's password.

## Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| `Insufficient privileges` changing the exclusion group | It is in the restricted unit | Assign Groups Administrator on the unit first (above) |
| `Instance cannot be destroyed` | `prevent_destroy` on the unit and the exclusion group | Intended. Removing them is a reviewed change to the code, never a `destroy` |
| CI plan fails with `AccessDenied` on `directoryRoles` | The plan identity lost `RoleManagement.Read.Directory` | Check `entra/bootstrap/graph.yaml` and run the Entra bootstrap |
