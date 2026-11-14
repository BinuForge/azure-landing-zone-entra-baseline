output "budget_name" {
  description = "Name of the subscription budget."
  value       = azurerm_consumption_budget_subscription.monthly.name
}

output "resource_group_names" {
  description = "Resource group per level component, keyed by component."
  value       = { for k, rg in azurerm_resource_group.this : k => rg.name }
}

output "resource_providers" {
  description = "Resource providers bootstrap registers."
  value       = local.resource_providers
}
