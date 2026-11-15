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

# An identifier, not a secret. Level 4 grants the runner its read roles (threat model C-06).
output "opsagent_runner_object_id" {
  description = "Object ID of lab-azure-l4-opsagent-run. Set as opsagent_runner_object_id in tfc/env/<tenant>.auto.tfvars."
  value       = azuread_service_principal.pipeline["azure-l4-opsagent-run"].object_id
}

output "report_store" {
  description = "Storage account and container of the ops agent's report store (ADR-0015)."
  value = {
    account   = azurerm_storage_account.reports.name
    container = azurerm_storage_container.reports.name
  }
}
