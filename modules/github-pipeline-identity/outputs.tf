output "client_id" {
  description = "Client ID of the app registration. Not a secret: only a federated token can sign in as it."
  value       = azuread_application.this.client_id
}

output "object_id" {
  description = "Object ID of the service principal, which permissions and roles are granted to."
  value       = azuread_service_principal.this.object_id
}

output "subject" {
  description = "The one federated credential subject the identity trusts."
  value       = azuread_application_federated_identity_credential.github.subject
}

output "environment" {
  description = "Name of the GitHub environment that unlocks the identity."
  value       = github_repository_environment.this.environment
}
