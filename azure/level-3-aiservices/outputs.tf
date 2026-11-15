# Read by level 4 consumers through tfe_outputs (ADR-0013).

output "account_id" {
  description = "Resource ID of the AI services account, the scope for data-plane role assignments."
  value       = azurerm_cognitive_account.this.id
}

output "account_endpoint" {
  description = "Account endpoint. Resolves to the private endpoint inside the network; not a secret."
  value       = azurerm_cognitive_account.this.endpoint
}

output "project_ids" {
  description = "Foundry project resource IDs, keyed by consumer."
  value       = { opsagent = azurerm_cognitive_account_project.opsagent.id }
}

output "deployment_names" {
  description = "Model deployment names callers use."
  value       = keys(azurerm_cognitive_deployment.this)
}

output "spoke_vnet_id" {
  description = "Resource ID of the AI services spoke."
  value       = azurerm_virtual_network.spoke.id
}

output "apim_subnet_id" {
  description = "Subnet reserved for the APIM gateway."
  value       = azurerm_subnet.this["apim"].id
}

output "prompt_workspace_id" {
  description = "Resource ID of the prompt content workspace. Readers are limited by design (ADR-0010)."
  value       = azurerm_log_analytics_workspace.prompts.id
}

output "gateway_url" {
  description = "AI gateway base URL for the OpenAI API, or null while APIM is off. Callers need an Entra token for gateway_audience with the AI.Invoke role."
  value       = var.enable_apim ? "${azapi_resource.apim[0].output.properties.gatewayUrl}/openai" : null
}

output "gateway_audience" {
  description = "Token audience callers request for the AI gateway."
  value       = local.gateway_audience
}
