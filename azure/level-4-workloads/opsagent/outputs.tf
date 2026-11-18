output "canary_nsg_name" {
  description = "Name of the canary NSG that carries the planted attacks for T-01 and T-09."
  value       = azurerm_network_security_group.canary.name
}

output "runner_role_scopes" {
  description = "Every scope where the runner holds a role, keyed by role. Checked by T-02."
  value = {
    config_reader = [for ra in azurerm_role_assignment.runner_config_reader : ra.scope]
    cost_reader   = [azurerm_role_assignment.runner_cost_reader.scope]
    ops_logs      = [azurerm_role_assignment.runner_ops_logs.scope]
  }
}
