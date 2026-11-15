# Runs with a mock provider: no sign-in, no network calls, nothing created.
mock_provider "azurerm" {
  mock_data "azurerm_resource_group" {
    defaults = {
      name     = "lab-rg-management-prd-ae"
      location = "australiaeast"
    }
  }
}

run "workspace_follows_naming_and_region" {
  command = plan

  assert {
    condition     = azurerm_log_analytics_workspace.ops.name == "lab-log-management-prd-ae"
    error_message = "The workspace name must follow docs/naming.md."
  }

  assert {
    condition     = azurerm_log_analytics_workspace.ops.location == "australiaeast"
    error_message = "The workspace must sit in the management group's region."
  }
}

run "ingestion_is_capped" {
  command = plan

  assert {
    condition     = azurerm_log_analytics_workspace.ops.daily_quota_gb > 0 && azurerm_log_analytics_workspace.ops.daily_quota_gb <= 5
    error_message = "Ingestion must have a daily cap: the only hard spend limit on this workspace."
  }

  assert {
    condition     = azurerm_log_analytics_workspace.ops.retention_in_days == 30
    error_message = "Retention must stay at the 30 days included in the price."
  }
}

run "no_shared_keys_and_resource_context_access" {
  command = plan

  assert {
    condition     = azurerm_log_analytics_workspace.ops.local_authentication_enabled == false
    error_message = "Shared keys must be off: Entra ID only."
  }

  assert {
    condition     = azurerm_log_analytics_workspace.ops.allow_resource_only_permissions == true
    error_message = "Resource-context access must be on, so readers see only their own resources' logs."
  }
}

run "uncapped_ingestion_is_rejected" {
  command = plan

  variables {
    daily_quota_gb = 0
  }

  expect_failures = [var.daily_quota_gb]
}
