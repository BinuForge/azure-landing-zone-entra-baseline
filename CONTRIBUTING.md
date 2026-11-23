# Contributing

The repository has one maintainer (ADR-0006), but every change follows the same path, and so would a
contribution. New here? Read [how it works](docs/how-it-works.md) first.

## How a change is made

1. Branch from `main`. Pushing to `main` is blocked by a ruleset.
2. Write the change and its test. A new control needs a test that fails when the control is broken.
3. Run the gates locally (below). They are the same ones `pr.yml` runs.
4. Open a pull request using the template. Commit messages follow
   [Conventional Commits](https://www.conventionalcommits.org/): `feat(entra): ...`, `fix(bootstrap): ...`.
5. Read the plan the pipeline posts on the pull request. A plan that destroys something needs a reason in
   the description.
6. After merge, the level's workflow plans again and waits for approval before applying the saved plan.

A significant decision gets an ADR in the same pull request (`docs/adr/0000-template.md`). Anything
added to HCP state is counted in `docs/cost.md`.

## Local gates

From the repository root, with the tools in `docs/runbooks/local-setup.md`:

```sh
pre-commit run --all-files            # fmt, validate, tflint, gitleaks and file hygiene
terraform -chdir=<level> test         # unit tests with mock providers
checkov --directory . --framework terraform github_actions --quiet --compact
```

Run checkov at the version pinned in `pr.yml`, in a virtual environment, not a system package: versions
differ in which checks they run.

## Rules that are not negotiable

- No tenant, subscription or object IDs, domains, credentials or personal data in any file.
- No client secrets. Pipelines authenticate with OIDC federation only.
- No pipeline identity gets a Tier 0 permission (ADR-0016). Tier 0 roots are run by a person.
- Actions are pinned by commit SHA; providers and tools by version (ADR-0001).
- Documentation is in Australian English and plain prose.
