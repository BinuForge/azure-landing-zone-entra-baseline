# Signs in with GitHub OIDC: ARM_USE_OIDC, ARM_CLIENT_ID, ARM_TENANT_ID and ARM_SUBSCRIPTION_ID come from
# the workflow environment (ADR-0012). No client secret exists.
provider "azurerm" {
  features {
    # A deleted AI account is otherwise soft-deleted with its name reserved, which leaves a teardown
    # incomplete and blocks the next deploy (docs/runbooks/destroy.md).
    cognitive_account {
      purge_soft_delete_on_destroy = true
    }
    log_analytics_workspace {
      permanently_delete_on_destroy = true
    }
    # A deleted APIM is kept for 48 hours with its name reserved.
    api_management {
      purge_soft_delete_on_destroy = true
      recover_soft_deleted         = false
    }
  }

  # Bootstrap registers resource providers; this level has no rights to.
  resource_provider_registrations = "none"
}

# Reads lower levels' outputs only (ADR-0013). TFE_TOKEN and TFE_ORGANIZATION come from the workflow.
provider "tfe" {}
