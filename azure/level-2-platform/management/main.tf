# Created by bootstrap, whose state is never shared, so looked up by name (ADR-0013).
data "azurerm_resource_group" "management" {
  name = "${var.prefix}-rg-management-prd-ae"
}

# The platform's operational log workspace. Prompt content never comes here: it has its own workspace in
# the AI services landing zone (ADR-0010).
resource "azurerm_log_analytics_workspace" "ops" {
  name                = "${var.prefix}-log-management-prd-ae"
  resource_group_name = data.azurerm_resource_group.management.name
  location            = data.azurerm_resource_group.management.location
  sku                 = "PerGB2018"
  retention_in_days   = var.retention_in_days
  daily_quota_gb      = var.daily_quota_gb

  # Entra ID only: no shared keys for agents or queries.
  local_authentication_enabled = false

  # Access follows the resource a log came from, so a reader of one resource cannot read the rest.
  allow_resource_only_permissions = true

  tags = {
    managed-by = "${var.prefix}-azure-l2-management-prd"
  }
}
