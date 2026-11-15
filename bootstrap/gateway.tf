locals {
  # The audience callers request a token for, and APIM checks. Tenant-scoped, so level 3 can build the same
  # value without reading this state. Version 1 tokens (the default) carry it as their audience.
  gateway_identifier_uri = "api://${data.azuread_client_config.current.tenant_id}/${var.prefix}-aigateway"

  # A fixed ID, so the role keeps its identity across applies. An identifier, not a secret.
  gateway_invoke_role_id = "9a86944a-470c-4f9f-bebf-6016ea769503"

  # Who may call the AI gateway. Each entry gets the AI.Invoke role (ADR-0008).
  gateway_callers = toset(["azure-l4-opsagent-run"])
}

# The AI gateway as an API in Entra. APIM validates tokens issued for it and requires the AI.Invoke role,
# so callers never hold a key and the model's own data-plane role stays with APIM alone.
resource "azuread_application" "gateway" {
  display_name     = "${var.prefix}-api-aigateway"
  description      = "AI gateway (APIM) as an API. Callers need the AI.Invoke app role. Created by bootstrap, ADR-0008."
  sign_in_audience = "AzureADMyOrg"
  identifier_uris  = [local.gateway_identifier_uri]
  owners           = [data.azuread_client_config.current.object_id]

  app_role {
    id                   = local.gateway_invoke_role_id
    value                = "AI.Invoke"
    display_name         = "Invoke AI models"
    description          = "Call models through the AI gateway, within the caller's token limit."
    allowed_member_types = ["Application"]
    enabled              = true
  }
}

resource "azuread_service_principal" "gateway" {
  client_id = azuread_application.gateway.client_id
  owners    = [data.azuread_client_config.current.object_id]

  # Entra issues tokens for the gateway only to identities assigned a role, so an unassigned identity in
  # the tenant cannot even get one. APIM checks the role as well.
  app_role_assignment_required = true
}

resource "azuread_app_role_assignment" "gateway_invoke" {
  for_each = local.gateway_callers

  app_role_id         = local.gateway_invoke_role_id
  principal_object_id = azuread_service_principal.pipeline[each.key].object_id
  resource_object_id  = azuread_service_principal.gateway.object_id
}
