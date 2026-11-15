# ADR-0005: Add the azapi and GitHub providers

- **Status:** Accepted
- **Date:** 2026-11-05

## Context

- ADR-0001 fixes the provider set and how each is pinned. This ADR extends it.
- Some Microsoft Foundry settings are not yet in azurerm. Guardrail egress rules, for example, exist
  only on a preview API version. TODO: link the API reference for the version used.
- The Azure Verified Modules pattern for Foundry is archived, so it cannot be the fallback.
  TODO: link the archived repository.
- Bootstrap creates GitHub environments. Their names appear in the
  [OIDC subject claim](https://docs.github.com/en/actions/security-for-github-actions/security-hardening-your-deployments/about-security-hardening-with-openid-connect)
  that each federated identity credential is pinned to, so an environment and its credential must be
  created together and kept in step.

## Options considered

| Option | For | Against |
|---|---|---|
| azapi and the GitHub provider | Everything stays in plans and state, so drift shows and destroy is complete | Two more providers to pin and track |
| Scripts using `az rest` and `gh` | No new providers | No plan, no drift detection, no destroy from state |
| Portal and settings-page steps | Quickest the first time | Not repeatable or reviewable, and easy to forget on teardown |

## Decision

Add `Azure/azapi` (`~> 2.13`) and `integrations/github` (`~> 6.13`), pinned and locked as ADR-0001
describes.

- azurerm comes first. azapi is used only where azurerm has no support, or where azurerm's
  implementation needs more privilege than the job. Each azapi resource carries a comment naming the
  reason and the API version it calls.
- Example of the second case: azurerm reads an APIM service by listing its delegation and tenant access
  secrets, so a read-only plan identity cannot plan it and the secrets land in state. Level 3 manages the
  service with azapi, which reads with a plain GET (2026-11-15).
- The GitHub provider is used only in `bootstrap/`, run from a person's machine, never from CI.

The providers were chosen over scripts and portal steps because the lab's evidence depends on being
able to plan, detect drift on and destroy everything it creates.

## Risks accepted

| Risk | Why it is accepted | Mitigation, or how we would notice |
|---|---|---|
| Preview APIs change or are retired | The features needed exist nowhere else | Labelled as preview in code and docs; a failed plan shows the change |
| azapi payloads are checked less strictly than azurerm schemas | The provider validates the shape, not every value | Post-deployment tests check the deployed result, not the payload |
| Bootstrap needs a GitHub token with repository administration rights | Creating environments requires it | Short-lived fine-grained token for this one repository, kept on the person's machine, never in CI or state inputs |

## Consequences

- Easier: more of the lab can be planned, tested and destroyed from code.
- Harder: two more providers for Dependabot and reviews, and preview API versions to watch.
- Revisit each azapi resource when azurerm adds support, and move it to azurerm in its own PR.
