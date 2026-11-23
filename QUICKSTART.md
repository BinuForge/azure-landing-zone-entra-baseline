# Quickstart: deploy your own copy

Deploy the whole lab into your own trial tenant and subscription, learn and test with it, then tear it
down. The runbooks in [`docs/runbooks/`](docs/runbooks/) hold the detail; this page puts them in order.

> **Use a new trial tenant only. Never a tenant people rely on.**
> The Entra levels change sign-in for everyone in the tenant: SMS and voice are switched off, users can
> no longer consent to apps, Conditional Access policies are created, and PIM rules are set. In a work
> tenant that can lock people out. Create the break-glass accounts (step 2) before anything else.

## What you need

| Item | Notes |
|---|---|
| A new Azure free account | Comes with a new Entra tenant and USD 200 credit for 30 days. Microsoft allows one per person |
| A Microsoft Entra ID P2 trial in that tenant | Free for 30 days. PIM and risk-based Conditional Access need it |
| A GitHub account | Fork this repository and keep the fork public: environment reviewers need a public repository on the free plan |
| An HCP Terraform account | A free organisation is enough |
| Tools on your machine | [`docs/runbooks/local-setup.md`](docs/runbooks/local-setup.md) (macOS; PowerShell notes are in the bootstrap runbook) |

## Time and cost

| | Time | Cost on the free credit |
|---|---|---|
| Setup and bootstrap | 2 to 3 hours the first time | Nothing |
| Azure levels 0 to 4 | About 2 hours, mostly API Management (30 to 60 minutes) | About AUD 3 a day while deployed, 80% of it API Management |
| Entra levels | About 1 hour | Nothing during the P2 trial |

A free trial with its spending limit on cannot charge your card. When the credit ends, Azure disables
the subscription instead of billing you. Never upgrade it to pay-as-you-go while resources are deployed:
they start billing straight away.

## Steps

1. **Fork and clone.** Replace `@BinuForge` in [`.github/CODEOWNERS`](.github/CODEOWNERS) with your
   GitHub name. Optionally change `publisherName` in
   [`azure/level-3-aiservices/apim.tf`](azure/level-3-aiservices/apim.tf); it is only a label.
2. **Create the two break-glass accounts by hand**, as in
   [`entra/break-glass/README.md`](entra/break-glass/README.md). The Entra levels check for them and
   fail if they are missing.
3. **Protect your own sign-in.** Register Microsoft Authenticator, and a device-bound passkey, for the
   account you work with. Entra level 1 switches SMS off, and a synced passkey (iCloud Keychain, a
   browser's password manager) is not accepted.
4. **Sign in** to the new tenant: `az login --tenant <tenant ID>`, `gh auth login`, `terraform login`.
5. **Pick a unique suffix** of 1 to 3 lowercase letters or digits, for example `k7q`. It goes on the
   three names that must be unique across Azure ([naming](docs/naming.md#names-unique-across-azure)).
   Set it on your fork and run the read-only preflight until it passes:

   ```sh
   gh variable set LAB_UNIQUE_SUFFIX --body k7q
   bash bootstrap/scripts/preflight.sh k7q
   ```

6. **Fill in the git-ignored variable files** from each `example.auto.tfvars`:
   `bootstrap/env/lab.auto.tfvars` (add `unique_suffix = "k7q"`), `entra/bootstrap/env/lab.auto.tfvars`
   and, after step 7, `tfc/env/lab.auto.tfvars`. The preflight prints your OIDC subject prefix.
7. **Bootstrap, as a person**, following [`docs/runbooks/bootstrap.md`](docs/runbooks/bootstrap.md) in
   order: `bootstrap/`, then `entra/bootstrap/`, then the pipeline secrets script, then `tfc/`.
8. **Deploy the Azure levels from GitHub Actions**, one at a time, approving each apply after reading its
   plan: `azure-l0`, `azure-l1`, `azure-l2`, `azure-l3`, `azure-l4`. Start each from the Actions tab, or
   `gh workflow run azure-l0.yml`.
9. **Deploy the Entra levels**:
   - `entra-l0-org` from Actions.
   - `entra/level-0-privileged`, applied by you: [`docs/runbooks/entra-privileged.md`](docs/runbooks/entra-privileged.md),
     including `pim/Set-Pim.ps1`.
   - `entra-l1-governance` from Actions. Read the check at the top of
     [`docs/runbooks/entra-governance.md`](docs/runbooks/entra-governance.md) before approving.
   - `entra-l1-ca` from Actions. Every policy starts report-only
     ([ADR-0017](docs/adr/0017-conditional-access-baseline.md)).
10. **See it work.** Run `gateway-tests`, then `opsagent`, then `agent-live-tests`, then `evidence`. The
    agent's report is in the report store ([`agents/opsagent/README.md`](agents/opsagent/README.md)).

## Tear down

- **Azure:** run `destroy` with target `all`, read each destroy plan, approve it. The leftovers check
  runs last ([`docs/runbooks/destroy.md`](docs/runbooks/destroy.md)). Bootstrap, management groups and
  policy stay; they cost nothing.
- **Or let the trial lapse.** The subscription is disabled when the credit ends and deleted some time
  after. Nothing is charged unless you upgrade.
- **Entra:** the tenant keeps its settings. That is harmless in a trial tenant you no longer use.

## Known limits

- The original lab was deployed and tested live in November 2026. A copy uses the same code plus the
  suffix, which CI and the mock tests cover; a full deployment of a copy has not been done yet. If you
  do one, an issue with what you found is welcome.
- Names and regions assume Australia East (`ae`), as in [`docs/naming.md`](docs/naming.md).
- HCP Terraform's free tier counts managed resources. The lab stays well under the limit
  ([`docs/cost.md`](docs/cost.md)).
