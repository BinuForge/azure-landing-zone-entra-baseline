# Authenticates with the maintainer's `az login`. Bootstrap is never run from CI (ADR-0012).
provider "azurerm" {
  features {}

  subscription_id = var.subscription_id

  # Providers are registered explicitly by bootstrap, so no level needs subscription-wide write rights.
  resource_provider_registrations = "none"
}
