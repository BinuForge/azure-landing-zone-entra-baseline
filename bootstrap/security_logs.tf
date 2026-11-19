locals {
  # Entra's audit, sign-in and risk logs. Workload identity risk needs Workload ID Premium, which the lab
  # does not have, and Graph activity logs would mostly record the lab's own pipelines.
  entra_log_categories = [
    "AuditLogs",
    "SignInLogs",
    "NonInteractiveUserSignInLogs",
    "ServicePrincipalSignInLogs",
    "ManagedIdentitySignInLogs",
    "RiskyUsers",
    "UserRiskEvents",
  ]
}

# Entra's logs go here, not to the ops workspace: the ops agent's runner reads that one, and sign-in logs
# are personal data. Bootstrap's group outlives every teardown and no pipeline identity holds a role in it
# that reads logs, so only the maintainer can query them (ADR-0016, decision 6).
resource "azurerm_log_analytics_workspace" "security" {
  name                = "${var.prefix}-log-security-prd-${local.region}"
  resource_group_name = azurerm_resource_group.this["bootstrap"].name
  location            = var.location
  sku                 = "PerGB2018"
  retention_in_days   = 90

  # A cap keeps the lab's cost fixed. At a bank there is no cap: a flood of sign-ins would stop logging.
  daily_quota_gb = 0.5

  # Entra ID only, and workspace permissions only: no shared keys, no reading through a resource's role.
  local_authentication_enabled    = false
  allow_resource_only_permissions = false

  tags = {
    managed-by = "${var.prefix}-${local.resource_groups.bootstrap.workspace}"
  }
}

# An Entra setting, but an Azure resource written through Azure Resource Manager to an Azure workspace, so
# it lives here rather than in entra/bootstrap. Creating it needs Global Administrator or Security
# Administrator, which no pipeline holds. Exporting sign-in logs needs Entra ID P1 or P2, so it stays off
# until the tenant has one.
resource "azurerm_monitor_aad_diagnostic_setting" "entra" {
  count = var.entra_diagnostics ? 1 : 0

  name                       = "${var.prefix}-diag-entra"
  log_analytics_workspace_id = azurerm_log_analytics_workspace.security.id

  dynamic "enabled_log" {
    for_each = local.entra_log_categories
    content {
      category = enabled_log.value
    }
  }
}
