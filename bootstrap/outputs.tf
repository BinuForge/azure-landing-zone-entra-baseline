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

# Client IDs are not secrets: they identify an app, and only a federated token can sign in as it.
output "identity_client_ids" {
  description = "Client ID per identity, keyed like azure-l2-apply. Set as AZURE_CLIENT_ID in the matching environment."
  value       = { for k, app in azuread_application.pipeline : k => app.client_id }
}

output "federated_subjects" {
  description = "Every federated credential subject, for review."
  value = merge(
    { for k, c in local.github_credentials : k => c.subject },
    { for k, c in local.hcp_credentials : k => c.subject },
  )
}
