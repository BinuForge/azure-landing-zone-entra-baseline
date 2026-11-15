# Read by higher levels through tfe_outputs (ADR-0013).

output "private_dns_zone_ids" {
  description = "Private DNS zone resource IDs, keyed cognitiveservices, openai, aiservices. Spokes attach private endpoints to these and link their VNet to them."
  value       = { for k, z in azurerm_private_dns_zone.this : k => z.id }
}

output "resource_group_name" {
  description = "Resource group holding the zones, where spokes create their VNet links."
  value       = data.azurerm_resource_group.dns.name
}
