# Bootstrap

Bootstrap is the only Terraform a person applies by hand. It creates everything the pipelines need
before they can run: the budget, resource providers, level resource groups, pipeline identities and
their federated credentials, role assignments and GitHub environments (ADR-0012). Treat it as Tier 0.

Never run it from CI, never `terraform destroy` it, and never add a resource that a level could own.

## What it creates

| File | Creates |
|---|---|
| `budget.tf` | Monthly budget with three actual and one forecast alert |
| `resource_groups.tf` | Resource provider registrations, one resource group per level component, a delete lock on the bootstrap group |
| `identities.tf` | Plan and apply app registrations per level, the ops agent runner, and their federated credentials |
| `rbac.yaml` | Every role a pipeline identity holds, one row each (ADR-0012, decision 8) |
| `rbac.tf` | Custom roles, delegation conditions, and the role assignments from `rbac.yaml` |
| `report_store.tf` | The ops agent's report store, its write-only role, and read access for the maintainer (ADR-0015) |
| `governance.tf` | Subscription placement, hierarchy settings and the maintainer's own access |
| `github.tf` | One GitHub environment per GitHub-federated identity, with branch rules, reviewers, variables and identifier secrets, plus level 4 plan and apply environments that hold only the HCP token |
| `scripts/set-pipeline-secrets.sh` | The HCP token and plan encryption keys, set outside Terraform |

## Prerequisites

- Tools from `docs/runbooks/local-setup.md`, signed in: `az login`, `gh auth login`, `terraform login`.
- Global Administrator in Entra, and Owner on the subscription.
- `bootstrap/env/lab.auto.tfvars`, copied from `env/example.auto.tfvars` and filled in. It is git-ignored;
  check with `git check-ignore -v bootstrap/env/lab.auto.tfvars`.

Commands below are bash. In PowerShell, set variables with `$env:NAME = "value"` instead of `export`,
and quote arguments that contain `=`, for example `"-var-file=env/lab.auto.tfvars"`.

## First run only

1. `export TF_CLOUD_ORGANIZATION=<org>` then `terraform init`. This creates the HCP workspace
   `lab-tfc-l0-bootstrap-prd`.
2. In HCP Terraform, open that workspace, then Settings, General, and set Execution Mode to Local. In
   remote mode the plan would run on HCP's servers without your `az login`.
3. In the Azure portal, open Management groups once. On a new tenant this creates the tenant root group
   that levels 0 and 1 are assigned to.

## Every run

Run from `bootstrap/`, on an up-to-date `main`, after the change has merged.

1. Elevate, only if the change touches role assignments at the root management group:
   Entra admin centre, Properties, "Access management for Azure resources", Yes. Then `az logout` and
   `az login` so the token carries the new rights.
2. Set the session variables:

   ```sh
   export TF_CLOUD_ORGANIZATION=<org>
   export GITHUB_TOKEN="$(gh auth token)"
   ```

3. Plan and apply the saved plan:

   ```sh
   terraform init
   terraform plan -var-file=env/lab.auto.tfvars -out=tfplan
   terraform apply tfplan
   unset GITHUB_TOKEN
   ```

   Read the plan before applying. A bootstrap plan that destroys anything needs a reason.

4. If you elevated, switch it back to No, then confirm it is gone. This must print nothing:

   ```sh
   az role assignment list --scope / --assignee "$(az ad signed-in-user show --query id -o tsv)" -o tsv
   ```

## Pipeline secrets

Run after the first apply that creates environments, and every 30 days to rotate.

1. In HCP Terraform, Settings, Teams, owners, create a team API token with a 30-day expiry.
2. Run the script and paste the token at the prompt. Input is hidden and never written to disk:

   ```sh
   bash bootstrap/scripts/set-pipeline-secrets.sh
   ```

3. Check the summary lists `TF_TOKEN_APP_TERRAFORM_IO` and `PLAN_ENCRYPTION_KEY` for every plan and
   apply environment, and nothing for `lab-azure-l4-opsagent-run`.

Rotating issues a new HCP token and new plan keys. Old plans cannot be decrypted afterwards, which is
fine: a saved plan is only valid for one day.

## HCP projects and workspaces (`tfc/`)

The `tfc/` root creates the projects, workspaces and variable sets in `tfc/workspaces.yaml`. Its own
workspace, `lab-tfc-l0-core-prd`, is created by its first `terraform init`, like bootstrap's.

1. Copy `tfc/env/example.auto.tfvars` to `tfc/env/lab.auto.tfvars` and fill in. The level 4 client IDs
   come from `terraform output identity_client_ids` in `bootstrap/` (keys `azure-l4-plan` and
   `azure-l4-apply`), the runner's object ID from `terraform output opsagent_runner_object_id`; tenant
   and subscription from `az account show --query "{tenant:tenantId, sub:id}"`.
2. From `tfc/`: `terraform init`, then set `lab-tfc-l0-core-prd` to Local execution in HCP, as for
   bootstrap.
3. `terraform plan -var-file=env/lab.auto.tfvars -out=tfplan`, read it, then `terraform apply tfplan`.
4. Check in HCP that level 0-3 workspaces show Local execution, `lab-azure-l4-opsagent-np` shows Remote,
   and the `lab-azure-workload-credentials` variable set is attached to it only.

Every resource in HCP state counts towards the Free tier's 500 managed resources. Check the count in
`docs/cost.md` when adding a level.

## Checks after a run

```sh
terraform output federated_subjects     # every subject names one environment, or one workspace and phase
gh api repos/<owner>/<repo>/environments --jq '.environments[].name'
az role assignment list --all --query "[?starts_with(description || '', 'Bootstrap')].roleDefinitionName" -o tsv | sort | uniq -c
```

In the Entra admin centre, every `lab-azure-*` app registration must show no client secrets or
certificates, only federated credentials.

## Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| `"organization" must be set in the cloud configuration` | `TF_CLOUD_ORGANIZATION` not set in this terminal | Set it. The pre-commit `terraform validate` hook needs it too, so set it before committing |
| `export` or `code` not recognised | The terminal is PowerShell | Use `$env:NAME = "value"`, or type `zsh` first |
| Provider not installed | A new provider was added | Run `terraform init` again |
| `AuthorizationFailed` at a management group scope | Not elevated, or the token predates elevation | Elevate, then `az logout` and `az login` |
| GitHub 401 or 403 | `GITHUB_TOKEN` not set, or set in another terminal | `export GITHUB_TOKEN="$(gh auth token)"` |
| Plan wants to replace an app or credential | A level or name changed in `tfc/workspaces.yaml` | Expected when renaming; every pipeline using it must be updated in the same change |
| Plan wants to replace a role assignment | Its key, role, scope or description changed in `rbac.yaml`, or its delegation condition changed in `rbac.tf` | Expected for a real change. For a rename, add a `moved` block in `rbac.tf` instead |
| Deleting a custom role hangs with "waiting for confirmation" | Azure has deleted it but still lists it for a few minutes | Stop with Ctrl+C, wait five minutes, then plan and apply again |
| Warning: `new_subscriptions_land_in_sandbox` | The tenant's default management group was changed outside Terraform | `az account management-group hierarchy-settings update --name <tenant-id> --default-management-group /providers/Microsoft.Management/managementGroups/lab-mg-sandbox` |
| `Invalid Hierarchy Settings creation parameters: expected format: '/providers/Microsoft.Management/managementGroups/ID'` | An in-place update of `azapi_resource.hierarchy_settings` sent the short name Azure stores | Apply with `-replace=azapi_resource.hierarchy_settings`, which sends the full ID from the config |
