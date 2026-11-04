# Instructions for AI assistants

These rules apply to any AI assistant that suggests or writes changes in this repository. They repeat
rules found elsewhere in the repo, so a suggestion can be checked against them.

## Content

- Nothing from any employer: no code, configuration, names, systems or internal details.
- No tenant IDs, subscription IDs, object IDs, IP ranges, secrets or tokens. Tenant values belong in
  git-ignored `env/*.auto.tfvars`, HCP variable sets or GitHub environment variables.
- Control mappings say the design "supports" a control, never that it "complies".
- Australian English, plain prose, no em dashes.
- If a fact cannot be checked against provider or Microsoft documentation, write `TODO` rather than
  guess.

## Terraform

- Follow `docs/naming.md` for every name.
- Pin as ADR-0001 and ADR-0005 describe, and commit `.terraform.lock.hcl` for every root.
- Use Azure Verified Modules first, azurerm next, azapi only where azurerm has no support, with a
  comment naming the missing feature and API version.
- Higher levels read lower levels' outputs; a lower level never reads a higher one.
- Anything that costs money continuously sits behind a flag that defaults to `false`.
- No client secrets. Pipelines authenticate with OIDC (ADR-0002).

## Workflows

- Pin every action to a full commit SHA, with the tag in a comment.
- Default `permissions: contents: read`; grant more per job only where needed.
- Apply only from `main`, from a saved plan, through an environment with a required reviewer.

## Commits

- Conventional commit messages (`docs(adr): ...`, `feat(azure): ...`, `fix: ...`).
- One logical change per commit.
