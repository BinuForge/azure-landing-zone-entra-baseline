# Read by higher levels through tfe_outputs (ADR-0013).

output "log_analytics_workspace_id" {
  description = "Resource ID of the ops Log Analytics workspace, for diagnostic settings in higher levels."
  value       = azurerm_log_analytics_workspace.ops.id
}

output "log_analytics_workspace_name" {
  description = "Name of the ops Log Analytics workspace."
  value       = azurerm_log_analytics_workspace.ops.name
}

output "resource_group_name" {
  description = "Resource group holding the management resources."
  value       = data.azurerm_resource_group.management.name
}
