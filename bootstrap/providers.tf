# Authenticates with the maintainer's `az login`. Bootstrap is never run from CI (ADR-0012).
provider "azurerm" {
  features {
    # The report store has shared keys off, so Terraform manages it through Azure Resource Manager only,
    # never through the storage data plane.
    storage {
      data_plane_available = false
    }
  }

  subscription_id = var.subscription_id

  # Only bootstrap registers providers, and only this list, so no level needs subscription-wide write
  # rights. Registration runs each time the provider starts and is safe to repeat.
  resource_provider_registrations = "none"
  resource_providers_to_register  = local.resource_providers
}

# Same `az login` session. Creating app registrations needs an Entra role such as Application
# Administrator; the maintainer's Global Administrator role covers it.
provider "azuread" {}

# Only for management group hierarchy settings, which azurerm has no resource for (ADR-0005).
provider "azapi" {}

# Token comes from GITHUB_TOKEN, set from `gh auth token` for the run only (ADR-0005). It needs admin
# rights on the repository to manage environments, and never leaves the maintainer's machine.
provider "github" {
  owner = var.github_owner
}
