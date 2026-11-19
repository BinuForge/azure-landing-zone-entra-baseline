# Authenticates with the maintainer's `az login`. Never run from CI (ADR-0016). Granting Graph permissions
# needs Global Administrator (or Privileged Role Administrator); no Azure role is needed.
provider "azuread" {}

# Token comes from GITHUB_TOKEN, set from `gh auth token` for the run only. It needs admin rights on the
# repository to manage environments, and never leaves the maintainer's machine.
provider "github" {
  owner = var.github_owner
}
