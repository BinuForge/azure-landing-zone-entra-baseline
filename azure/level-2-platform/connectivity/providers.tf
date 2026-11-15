# Signs in with GitHub OIDC: ARM_USE_OIDC, ARM_CLIENT_ID, ARM_TENANT_ID and ARM_SUBSCRIPTION_ID come from
# the workflow environment (ADR-0012). No client secret exists.
provider "azurerm" {
  features {}

  # Bootstrap registers resource providers; this level has no rights to.
  resource_provider_registrations = "none"
}
