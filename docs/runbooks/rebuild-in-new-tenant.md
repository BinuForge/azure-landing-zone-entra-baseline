# Rebuild the lab in a new tenant

Moves this repository to a new tenant and subscription when the old ones end, for example when a free
account's credit runs out (ADR-0004). The repository, its history and its evidence stay. A new HCP
Terraform organisation gives every level fresh state, and the old organisation stays as a read-only record
of the old lab: every workspace keeps the state of its last apply.

To deploy a separate copy in your own fork instead, use the [quickstart](../../QUICKSTART.md).

## Why a new HCP organisation

The workspaces hold state for resources in the old tenant. Pointed at a new tenant, every plan would try to
refresh objects it can no longer reach. A new organisation starts clean, and nothing in the old one has to
be deleted or moved.

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

## Set up the new accounts

1. A new Microsoft account and Azure free account: a new tenant and subscription.
2. In the new tenant, start the Entra ID P2 trial, create the two break-glass accounts
   ([break-glass](../../entra/break-glass/README.md)), and register Microsoft Authenticator and a
   device-bound passkey for your daily admin.
3. A new free HCP Terraform organisation under your existing HCP login. Keep the old one.

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

3. Update the git-ignored variable files: in `bootstrap/env/lab.auto.tfvars`, the new `subscription_id`,
   `hcp_organization` and `unique_suffix`; in `entra/bootstrap/env/lab.auto.tfvars` and
   `tfc/env/lab.auto.tfvars`, the new organisation. The OIDC subject prefix does not change: it belongs
   to the repository.
4. In every root you run locally (`bootstrap/`, `entra/bootstrap/`, `tfc/`, `entra/level-0-privileged/`),
   re-initialise against the new organisation. Nothing is migrated:

   ```sh
   export TF_CLOUD_ORGANIZATION=<new organisation>
   terraform init -reconfigure
   ```

## Deploy

Follow [bootstrap](bootstrap.md) as a first run, then steps 8 to 10 of the [quickstart](../../QUICKSTART.md):
the Azure levels, the Entra levels and the live tests. When the new lab is up, switch drift back on with
`gh workflow enable drift.yml`.

## Afterwards

- Revoke the old organisation's team API token in HCP Terraform. The pipelines now use the new one.
- Earlier evidence packs stay valid as a record of the old lab: each is attested to the run that made it.
- The old tenant keeps its Entra settings. Nothing in it costs anything.
