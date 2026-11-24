# Rebuild the lab in a new tenant

Moves this repository to a new tenant and subscription when the old ones end, for example when a free
account's credit runs out (ADR-0004). The repository, its history and its evidence stay. The HCP Terraform
organisation stays too, but every old workspace is deleted, so the new lab starts with fresh state and
nothing stale is left behind. The signed evidence packs are the record of the old lab, not its state.

To deploy a separate copy in your own fork instead, use the [quickstart](../../QUICKSTART.md).

## Why the old workspaces are deleted

They hold state for resources in the old tenant. Pointed at a new tenant, every plan would try to refresh
objects it can no longer reach. Old state is also a poor record: it can hold sensitive values, and the
attested evidence packs already show what existed. Bootstrap and `tfc/` recreate every workspace.

## Why a unique suffix

The old lab's global names stay taken after it ends. A disabled subscription keeps its resources for up to
90 days, including the report store in the bootstrap group, which teardown leaves on purpose. A deleted
Foundry account or API Management service also holds its name for a while. So the new lab sets
`unique_suffix` ([naming](../naming.md#names-unique-across-azure), ADR-0020).

## Before the old subscription ends

1. Collect evidence while the lab still works: `evidence`, `gateway-tests` and `agent-live-tests`
   ([evidence](evidence.md)).
2. Tear down with `destroy`, target `all` ([destroy](destroy.md)), then collect a `-teardown` evidence pack.
   If the subscription ends first, nothing is charged; you only lose the teardown pack.
3. Switch off the nightly drift check, which would fail every night once the subscription is disabled:

   ```sh
   gh workflow disable drift.yml
   ```

4. Delete the old HCP workspaces, from `tfc/` on an up-to-date `main`. The first apply only records the
   switch; the destroy then removes the twelve level workspaces, the projects and the variable sets, even
   though they still hold state. The script removes the three workspaces that hold the person-run roots'
   own state, which Terraform cannot delete:

   ```sh
   export TF_CLOUD_ORGANIZATION=<organisation>
   terraform init
   terraform apply -var-file=env/lab.auto.tfvars -var allow_force_delete=true
   terraform destroy -var-file=env/lab.auto.tfvars -var allow_force_delete=true
   cd .. && bash tfc/scripts/delete-root-workspaces.sh <organisation>
   ```

   The Azure and Entra objects are not touched: the old subscription is going, and the old tenant is left.

## Set up the new accounts

1. A new Microsoft account and Azure free account: a new tenant and subscription.
2. In the new tenant, start the Entra ID P2 trial, create the two break-glass accounts
   ([break-glass](../../entra/break-glass/README.md)), and register Microsoft Authenticator and a
   device-bound passkey for your daily admin.
3. If the new tenant should use your custom domain, remove it from the old tenant first: a domain can be
   verified in only one tenant, and users whose sign-in name uses it must be renamed or deleted before it
   can be removed. Otherwise use the new tenant's `onmicrosoft.com` domain.

## Point the repository at the new tenant

1. Delete the old GitHub environments. They hold the old tenant's identifiers, and bootstrap creates their
   variables afresh, which fails if they already exist. Deployment history stays.

   ```sh
   REPO=BinuForge/azure-landing-zone-entra-baseline
   gh api "repos/$REPO/environments" --jq '.environments[].name' | grep '^lab-' |
     while read -r env; do gh api -X DELETE "repos/$REPO/environments/$env" && echo "deleted $env"; done
   ```

2. Set the suffix and run the preflight, signed in to the new tenant (`az login --tenant <tenant ID>`):

   ```sh
   gh variable set LAB_UNIQUE_SUFFIX --body <suffix>
   bash bootstrap/scripts/preflight.sh <suffix>
   ```

3. Update the git-ignored variable files: in `bootstrap/env/lab.auto.tfvars`, the new `subscription_id`
   and `unique_suffix`; in `tfc/env/lab.auto.tfvars`, the new tenant and subscription IDs. The organisation
   and the OIDC subject prefix do not change.
4. In every root you run locally (`bootstrap/`, `entra/bootstrap/`, `tfc/`, `entra/level-0-privileged/`),
   remove the old local working state, because its workspace no longer exists, then initialise again:

   ```sh
   rm -rf .terraform
   terraform init
   ```

## Deploy

Follow [bootstrap](bootstrap.md) as a first run, then steps 8 to 10 of the [quickstart](../../QUICKSTART.md):
the Azure levels, the Entra levels and the live tests. When the new lab is up, switch drift back on with
`gh workflow enable drift.yml`.

## Afterwards

- Rotate the HCP team API token: run the pipeline secrets script with a new token ([bootstrap](bootstrap.md#pipeline-secrets)).
- Earlier evidence packs stay valid as a record of the old lab: each is attested to the run that made it.
- The old tenant keeps its Entra settings. Nothing in it costs anything.
