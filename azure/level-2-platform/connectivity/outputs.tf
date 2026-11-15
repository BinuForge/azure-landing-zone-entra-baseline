# Read by higher levels through tfe_outputs (ADR-0013).

output "hub_vnet_id" {
  description = "Resource ID of the hub VNet, for private DNS zone links and spoke peering."
  value       = azurerm_virtual_network.hub.id
}

output "hub_vnet_name" {
  description = "Name of the hub VNet."
  value       = azurerm_virtual_network.hub.name
}

output "resource_group_name" {
  description = "Resource group holding the hub, where spokes create their side of the peering."
  value       = data.azurerm_resource_group.connectivity.name
}

output "hub_address_space" {
  description = "Hub range, so spokes can check they do not overlap it."
  value       = var.hub_address_space
}
