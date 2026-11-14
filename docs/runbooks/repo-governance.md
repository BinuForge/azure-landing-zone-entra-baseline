# Repository governance

How changes reach `main` and how applies are approved, the GitHub settings behind it, and how to
check each one. ADR-0006 explains why approvals work this way with one maintainer.

## Why this matters

The pipelines can change Azure and Entra. Whoever can merge to `main` or approve an environment can
deploy. These settings are the controls on that path; without them, a push to `main` would skip every
PR gate, and an apply would run without anyone confirming the plan.

## Current state

The repository went public on 2026-11-14, after a full-history gitleaks scan with no findings. On GitHub
Free, rulesets, environments with required reviewers, secret scanning and artifact attestations are only
available to public repositories, which is why it is public.

Applied on 2026-11-14: merging, both rulesets, Actions settings and security features. Environments
are created by bootstrap, so their rows below are still the target until bootstrap runs.

## Target settings

### Merging

| Setting | Value | Why |
|---|---|---|
| Allowed merge methods | Squash only | One commit per pull request keeps `main` readable |
| Automatically delete head branches | On | Merged branches do not pile up |
| Default branch | `main` | Applies run only from `main` |

### Ruleset on `main`

| Rule | Value | Why |
|---|---|---|
| Require a pull request | On, 0 required approvals | Every change runs the gates; approvals cannot be required with one maintainer (ADR-0006) |
| Required status checks | `discover`, `secrets-scan`, `iac-scan` and each `terraform (<root>) / <root>` check | A failing gate blocks the merge. Each new Terraform root adds a check, and the ruleset is updated in the same PR |
| Block force pushes | On | History on `main` cannot be rewritten by accident |
| Restrict deletions | On | `main` cannot be deleted |
| Bypass | Repository admin only | A solo maintainer needs a way to recover; bypasses are logged |

### Tags

A ruleset on tags matching `azure/*` restricts creating, updating and deleting them, because module
releases are consumed by tag.

### Environments

| Environment | Deployment branches | Required reviewer | Secrets |
|---|---|---|---|
| `<prefix>-<area>-<level>-plan` | Any branch in this repository | None | HCP token, plan identity client ID |
| `<prefix>-<area>-<level>-apply` | `main` only | The maintainer, self-review allowed | HCP token, apply identity client ID |

Environment names match the identity they unlock (`docs/naming.md`), because the federated credential
subject contains the environment name. Bootstrap creates them (ADR-0005).

### Actions

| Setting | Value | Why |
|---|---|---|
| Default workflow permissions | Read repository contents | Each workflow asks for more per job |
| Allow Actions to create and approve pull requests | Off | A workflow cannot approve its own change |
| Require actions pinned to a full commit SHA | On (`sha_pinning_required` in the Actions permissions API) | Matches ADR-0001; a workflow using a tag instead of a SHA fails |
| Fork pull request workflows | Require approval for all outside collaborators | Forks never get secrets, and do not run unreviewed |

### Security features

| Feature | Value |
|---|---|
| Dependabot alerts and security updates | On |
| Secret scanning and push protection | On (free for public repositories) |
| Private vulnerability reporting | On |

## Checking the settings

To check the current settings:

```sh
R=BinuForge/azure-landing-zone-entra-baseline
gh api repos/$R --jq '{allow_squash_merge, allow_merge_commit, allow_rebase_merge, delete_branch_on_merge}'
gh api repos/$R/rulesets
gh api repos/$R/environments --jq '.environments[] | {name, protection_rules}'
gh api repos/$R/actions/permissions/workflow
```

Expected: only squash allowed, branch deletion on, a ruleset targeting `main`, and every `-apply`
environment with a `required_reviewers` rule.
