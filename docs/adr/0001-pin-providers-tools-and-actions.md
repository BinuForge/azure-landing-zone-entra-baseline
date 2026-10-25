# ADR-0001: Pin providers, tools and CI actions

- **Status:** Accepted
- **Date:** 2026-10-25

## Context

- A saved plan can only be applied by the same provider versions that produced it, so plan and apply
  must resolve identical versions.
- azurerm 5.0 was released on 2026-07-28. The Azure Verified Modules this repo builds on still
  constrain `azurerm < 5.0` (for example `avm-res-keyvault-vault` 0.12.0 requires `>= 4.81, < 5.0`).
- Several CI supply-chain compromises in 2025 and 2026 worked by moving a mutable action tag
  (for example `v1`) to malicious code. A commit SHA cannot be moved.

## Decision

| Component | Constraint | Why |
|---|---|---|
| Terraform | `>= 1.9` in code, `1.17.0` exact in CI | 1.9 brings cross-variable validation; CI pins one version so plans are reproducible. |
| `hashicorp/azurerm` | `~> 4.81` | Latest 4.x; AVM compatible. Move to 5.x when AVM does, in its own PR. |
| `hashicorp/azuread` | `~> 3.10` | Includes `azuread_application_flexible_federated_identity_credential`. |
| `hashicorp/tfe` | `~> 0.82` | `tfe_workspace_settings` replaces the deprecated execution arguments on `tfe_workspace`. |
| `microsoft/msgraph` | `0.6.0` exact | Pre-1.0 provider: minor versions may break, so every bump is a reviewed PR. |
| GitHub Actions | full commit SHA, tag in a comment | Tags can be moved; SHAs cannot. |
| CLI tools in CI | exact version, checksum verified where downloaded | Same reason. |

`.terraform.lock.hcl` is committed for every root, with hashes for `linux_amd64` (CI) and
`darwin_arm64` (local):

```sh
terraform providers lock -platform=linux_amd64 -platform=darwin_arm64
```

## Consequences

- Upgrades are deliberate: Dependabot opens a PR, the PR gates run, a person merges.
- Pinning by SHA means security fixes in actions also wait for that PR. Dependabot is weekly to keep
  the gap short.
- When AVM supports azurerm 5.x, this ADR is superseded.

## Alternatives considered

| Option | Why not |
|---|---|
| Float on major versions (`~> 4`, `@v7`) | A plan made on Monday may not apply on Tuesday; moved tags run unreviewed code. |
| azurerm 5.x now | Breaks AVM modules or forces local forks of them. |
