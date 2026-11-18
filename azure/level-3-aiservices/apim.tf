# The AI gateway (ADR-0008): the only identity that can call Foundry. External VNet mode, because the ops
# agent's runner is on the internet; identity, not network position, does the gatekeeping. Behind a cost
# flag, off by default.

data "azurerm_client_config" "current" {}

locals {
  apim = var.enable_apim ? 1 : 0

  # Same tenant-scoped audience bootstrap gives the gateway app (bootstrap/gateway.tf).
  gateway_audience = "api://${data.azurerm_client_config.current.tenant_id}/${var.prefix}-aigateway"
  kill_switch_name = "ai-kill-switch"

  # Traffic APIM needs in a VNet, and nothing else. Outbound internet is denied apart from port 80 for
  # certificate revocation checks, and 443 to Azure for log ingestion. APIM sends gateway logs to
  # gcs.prod.warm.ingestion.monitoring.azure.com, which sits outside the AzureMonitor tag, so with the deny
  # rule alone no gateway log ever arrived (found while building T-13). A network security group cannot
  # name a host, so the narrowest rule it can express is the AzureCloud tag. At a bank, egress goes
  # through the hub firewall, which allows that host by name (ADR-0008).
  apim_nsg_rules = {
    "allow-clients-https"    = { priority = 100, direction = "Inbound", source = "Internet", destination = "VirtualNetwork", ports = ["443"] }
    "allow-apim-management"  = { priority = 110, direction = "Inbound", source = "ApiManagement", destination = "VirtualNetwork", ports = ["3443"] }
    "allow-load-balancer"    = { priority = 120, direction = "Inbound", source = "AzureLoadBalancer", destination = "VirtualNetwork", ports = ["6390"] }
    "allow-storage"          = { priority = 100, direction = "Outbound", source = "VirtualNetwork", destination = "Storage", ports = ["443"] }
    "allow-sql"              = { priority = 110, direction = "Outbound", source = "VirtualNetwork", destination = "Sql", ports = ["1433"] }
    "allow-key-vault"        = { priority = 120, direction = "Outbound", source = "VirtualNetwork", destination = "AzureKeyVault", ports = ["443"] }
    "allow-monitor"          = { priority = 130, direction = "Outbound", source = "VirtualNetwork", destination = "AzureMonitor", ports = ["443", "1886"] }
    "allow-entra"            = { priority = 140, direction = "Outbound", source = "VirtualNetwork", destination = "AzureActiveDirectory", ports = ["443"] }
    "allow-monitor-ingest"   = { priority = 145, direction = "Outbound", source = "VirtualNetwork", destination = "AzureCloud", ports = ["443"] }
    "allow-foundry-endpoint" = { priority = 150, direction = "Outbound", source = "VirtualNetwork", destination = local.subnets.privateendpoints, ports = ["443"] }
    "allow-certificate-crl"  = { priority = 160, direction = "Outbound", source = "VirtualNetwork", destination = "Internet", ports = ["80"] }
    "deny-internet-outbound" = { priority = 4000, direction = "Outbound", source = "VirtualNetwork", destination = "Internet", ports = ["*"], access = "Deny" }
  }
}

resource "azurerm_network_security_rule" "apim" {
  for_each = local.apim_nsg_rules

  name                        = each.key
  resource_group_name         = local.rg
  network_security_group_name = azurerm_network_security_group.this["apim"].name
  priority                    = each.value.priority
  direction                   = each.value.direction
  access                      = try(each.value.access, "Allow")
  protocol                    = "Tcp"
  source_port_range           = "*"
  # Azure accepts "*" only as a single range, never inside a list of ranges.
  destination_port_range     = contains(each.value.ports, "*") ? "*" : null
  destination_port_ranges    = contains(each.value.ports, "*") ? null : each.value.ports
  source_address_prefix      = each.value.source
  destination_address_prefix = each.value.destination
}

resource "azurerm_public_ip" "apim" {
  count = local.apim

  # Exempt from the corp no-public-IP policy, mitigated by the gateway's identity controls (level 1).
  name                = "${var.prefix}-pip-apim-prd-ae"
  resource_group_name = local.rg
  location            = local.location
  sku                 = "Standard"
  allocation_method   = "Static"
  domain_name_label   = "${var.prefix}-apim-aiservices-prd-ae"
  tags                = local.tags
}

# The APIM service is managed with azapi, not azurerm (ADR-0005). azurerm's read lists the developer
# portal's delegation key and the tenant access keys on every plan, so a read-only plan identity cannot
# plan, and those secrets sit in state. azapi reads with a plain GET: no secret is read or stored.
# Microsoft.ApiManagement/service, API version 2024-05-01.
moved {
  from = azurerm_api_management.this[0]
  to   = azapi_resource.apim[0]
}

locals {
  apim_name = "${var.prefix}-apim-aiservices-prd-ae"

  # TLS 1.2 or later only, at the gateway and to backends; no 3DES, and only forward-secret ECDHE suites
  # stay on. Written out, not left to defaults, so the service keeps them whatever its creation date.
  apim_disabled_ciphers = [
    "TLS_ECDHE_ECDSA_WITH_AES_128_CBC_SHA", "TLS_ECDHE_ECDSA_WITH_AES_256_CBC_SHA",
    "TLS_ECDHE_RSA_WITH_AES_128_CBC_SHA", "TLS_ECDHE_RSA_WITH_AES_256_CBC_SHA",
    "TLS_RSA_WITH_AES_128_CBC_SHA", "TLS_RSA_WITH_AES_128_CBC_SHA256", "TLS_RSA_WITH_AES_128_GCM_SHA256",
    "TLS_RSA_WITH_AES_256_CBC_SHA", "TLS_RSA_WITH_AES_256_CBC_SHA256", "TLS_RSA_WITH_AES_256_GCM_SHA384",
    "TripleDes168",
  ]
  apim_custom_properties = merge(
    { for p in ["Ssl30", "Tls10", "Tls11"] : "Microsoft.WindowsAzure.ApiManagement.Gateway.Security.Protocols.${p}" => "false" },
    { for p in ["Ssl30", "Tls10", "Tls11"] : "Microsoft.WindowsAzure.ApiManagement.Gateway.Security.Backend.Protocols.${p}" => "false" },
    { for c in local.apim_disabled_ciphers : "Microsoft.WindowsAzure.ApiManagement.Gateway.Security.Ciphers.${c}" => "false" },
    # Azure reports this one capitalised; matching it keeps plans clean.
    { "Microsoft.WindowsAzure.ApiManagement.Gateway.Protocols.Server.Http2" = "False" },
  )
}

resource "azapi_resource" "apim" {
  count = local.apim

  # External mode on purpose: the runner is on the internet and every call needs an Entra token with the
  # AI.Invoke role (ADR-0008).
  type      = "Microsoft.ApiManagement/service@2024-05-01"
  name      = local.apim_name
  parent_id = data.azurerm_resource_group.aiservices.id
  location  = local.location
  tags      = local.tags

  identity {
    type = "SystemAssigned"
  }

  body = {
    sku = {
      name     = "Developer"
      capacity = 1
    }
    properties = {
      publisherName        = "BinuForge lab"
      publisherEmail       = var.apim_publisher_email
      virtualNetworkType   = "External"
      publicIpAddressId    = azurerm_public_ip.apim[0].id
      publicNetworkAccess  = "Enabled"
      apiVersionConstraint = { minApiVersion = "2021-08-01" }
      customProperties     = local.apim_custom_properties
      virtualNetworkConfiguration = {
        subnetResourceId = azurerm_subnet.this["apim"].id
      }
    }
  }

  response_export_values = ["properties.gatewayUrl"]

  # Creating APIM in a virtual network takes 30 to 60 minutes.
  timeouts {
    create = "2h"
    update = "2h"
    delete = "1h"
  }

  depends_on = [azurerm_network_security_rule.apim, azapi_resource_action.apim_purge]
}

# A deleted APIM is kept for 48 hours with its name reserved, which blocks the next deploy. azurerm purged
# it; with azapi, this action does, at destroy time only. The service depends on it, so the service is
# destroyed first and the purge runs after (docs/runbooks/destroy.md). Needs bootstrap's purger role.
resource "azapi_resource_action" "apim_purge" {
  count = local.apim

  type        = "Microsoft.ApiManagement/locations/deletedservices@2024-05-01"
  resource_id = "/subscriptions/${data.azurerm_client_config.current.subscription_id}/providers/Microsoft.ApiManagement/locations/${local.location}/deletedservices/${local.apim_name}"
  method      = "DELETE"
  when        = "destroy"
}

# The kill switch's value is changed by the runbook, in seconds, so Terraform deliberately leaves it alone.
resource "azurerm_api_management_named_value" "kill_switch" {
  count = local.apim

  name                = local.kill_switch_name
  display_name        = local.kill_switch_name
  resource_group_name = local.rg
  api_management_name = azapi_resource.apim[0].name
  value               = "false"

  lifecycle {
    ignore_changes = [value]
  }
}

resource "azurerm_api_management_api" "openai" {
  count = local.apim

  name                  = "openai"
  display_name          = "Azure OpenAI through the AI gateway"
  resource_group_name   = local.rg
  api_management_name   = azapi_resource.apim[0].name
  revision              = "1"
  path                  = "openai"
  protocols             = ["https"]
  service_url           = "https://${azurerm_cognitive_account.this.custom_subdomain_name}.openai.azure.com/openai"
  subscription_required = false # Callers authenticate with Entra tokens, never subscription keys.
}

# One operation: chat completions. Nothing else on the model endpoint is exposed.
resource "azurerm_api_management_api_operation" "chat" {
  count = local.apim

  operation_id        = "chat-completions"
  api_name            = azurerm_api_management_api.openai[0].name
  api_management_name = azapi_resource.apim[0].name
  resource_group_name = local.rg
  display_name        = "Chat completions"
  method              = "POST"
  url_template        = "/deployments/{deployment-id}/chat/completions"

  template_parameter {
    name     = "deployment-id"
    type     = "string"
    required = true
    values   = keys(var.model_deployments)
  }
}

resource "azurerm_api_management_api_policy" "openai" {
  count = local.apim

  api_name            = azurerm_api_management_api.openai[0].name
  api_management_name = azapi_resource.apim[0].name
  resource_group_name = local.rg

  xml_content = templatefile("${path.module}/policies/ai-gateway.xml.tftpl", {
    tenant_id         = data.azurerm_client_config.current.tenant_id
    audience          = local.gateway_audience
    tokens_per_minute = var.gateway_tokens_per_minute
    kill_switch       = local.kill_switch_name
  })

  depends_on = [azurerm_api_management_named_value.kill_switch]

  lifecycle {
    # One caller must not be able to use a whole deployment's capacity.
    precondition {
      condition     = var.gateway_tokens_per_minute < min([for d in values(var.model_deployments) : d.capacity]...) * 1000
      error_message = "gateway_tokens_per_minute must be below the smallest deployment's capacity."
    }
  }
}

# The only data-plane role on Foundry (ADR-0008). Allowed by this level's role assignment condition.
resource "azurerm_role_assignment" "apim_openai_user" {
  count = local.apim

  scope                = azurerm_cognitive_account.this.id
  role_definition_name = "Cognitive Services OpenAI User"
  principal_id         = azapi_resource.apim[0].identity[0].principal_id
  principal_type       = "ServicePrincipal"
  description          = "AI gateway, ADR-0008. The only caller allowed on the model."
}

# The run ID travels from the caller to the model (threat model C-22). Gateway logs record it and the ID
# sent on to Foundry, and never a request or response body or the caller's IP (ADR-0010). Turning on
# gateway logs (apim_ops) makes Azure create this diagnostic with defaults that log the caller's IP, so
# it is created before apim_ops. The lab's copy was imported once (PR #41).
resource "azurerm_api_management_diagnostic" "azuremonitor" {
  count = local.apim

  identifier               = "azuremonitor"
  resource_group_name      = local.rg
  api_management_name      = azapi_resource.apim[0].name
  api_management_logger_id = "${azapi_resource.apim[0].id}/loggers/azuremonitor"
  sampling_percentage      = 100
  always_log_errors        = true
  log_client_ip            = false
  verbosity                = "information"

  frontend_request {
    headers_to_log = ["x-correlation-id"]
    body_bytes     = 0

    data_masking {
      query_params {
        mode  = "Hide"
        value = "*"
      }
    }
  }

  backend_request {
    headers_to_log = ["x-ms-client-request-id"]
    body_bytes     = 0

    data_masking {
      query_params {
        mode  = "Hide"
        value = "*"
      }
    }
  }

  frontend_response {
    body_bytes = 0
  }

  backend_response {
    body_bytes = 0
  }
}

resource "azurerm_monitor_diagnostic_setting" "apim_ops" {
  count = local.apim

  name                       = "${var.prefix}-diag-apim-ops"
  target_resource_id         = azapi_resource.apim[0].id
  log_analytics_workspace_id = local.management.log_analytics_workspace_id

  enabled_log {
    category = "GatewayLogs"
  }

  enabled_metric {
    category = "AllMetrics"
  }

  depends_on = [azurerm_api_management_diagnostic.azuremonitor]
}
