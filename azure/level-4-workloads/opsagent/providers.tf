# HCP dynamic credentials: the lab-azure-workload-credentials variable set sets TFC_AZURE_PROVIDER_AUTH and
# one client ID per run phase, so plans sign in as lab-azure-l4-plan and applies as lab-azure-l4-apply
# (tfc/workspaces.yaml). No client secret exists.
provider "azurerm" {
  features {}

  # Bootstrap registers resource providers; this level has no rights to.
  resource_provider_registrations = "none"
}

# Reads lower levels' outputs only (ADR-0013). In a remote run the provider uses the run's own token,
# which can read only the workspaces that share state with this one (tfc/workspaces.yaml, reads). The
# organisation comes from TFE_ORGANIZATION on the workspace's inputs variable set.
provider "tfe" {}
