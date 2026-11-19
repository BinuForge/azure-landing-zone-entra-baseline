# Client IDs are not secrets: they identify an app, and only a federated token can sign in as it.
output "identity_client_ids" {
  description = "Client ID per identity, keyed like entra-l1-ca-apply. Set as AZURE_CLIENT_ID in the matching environment."
  value       = { for k, id in module.identity : k => id.client_id }
}

output "federated_subjects" {
  description = "Every federated credential subject, for review."
  value       = { for k, id in module.identity : k => id.subject }
}
