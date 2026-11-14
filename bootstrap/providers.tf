# Authenticates with the maintainer's `az login`. Bootstrap is never run from CI (ADR-0012).
provider "azurerm" {
  features {}

  subscription_id = var.subscription_id

  # Only bootstrap registers providers, and only this list, so no level needs subscription-wide write
  # rights. Registration runs each time the provider starts and is safe to repeat.
  resource_provider_registrations = "none"
  resource_providers_to_register  = local.resource_providers
}

# Same `az login` session. Creating app registrations needs an Entra role such as Application
# Administrator; the maintainer's Global Administrator role covers it.
provider "azuread" {}
