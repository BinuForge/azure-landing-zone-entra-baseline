# The runner's read roles (threat model C-06). Level 4's apply identity may grant only these, through the
# delegation conditions bootstrap sets (ADR-0012): the config reader and Cost Management Reader anywhere in
# the subscription, Log Analytics Reader on the management group only. None of them can write (T-02).

# Configuration, never log data: the config reader is Reader without the log reads (ADR-0012, decision 6).
resource "azurerm_role_assignment" "runner_config_reader" {
  for_each = data.azurerm_resource_group.this

  scope                = each.value.id
  role_definition_name = "${var.prefix}-role-config-reader"
  principal_id         = var.runner_object_id
  principal_type       = "ServicePrincipal"
  description          = "Level 4. The ops agent reads configuration in this group (threat model C-06)."
}

# Cost data is subscription-wide in Cost Management; there is no narrower scope for it.
resource "azurerm_role_assignment" "runner_cost_reader" {
  scope                = local.subscription
  role_definition_name = "Cost Management Reader"
  principal_id         = var.runner_object_id
  principal_type       = "ServicePrincipal"
  description          = "Level 4. The ops agent reads cost by service and by resource group (threat model C-06)."
}

# The one place the runner may query logs: the ops workspace, never the prompt workspace (T-10).
resource "azurerm_role_assignment" "runner_ops_logs" {
  scope                = local.management.log_analytics_workspace_id
  role_definition_name = "Log Analytics Reader"
  principal_id         = var.runner_object_id
  principal_type       = "ServicePrincipal"
  description          = "Level 4. The ops agent reads ingestion and usage in the ops workspace (threat model C-06)."
}
