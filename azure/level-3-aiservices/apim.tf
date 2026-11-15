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
  # certificate revocation checks.
  apim_nsg_rules = {
    "allow-clients-https"    = { priority = 100, direction = "Inbound", source = "Internet", destination = "VirtualNetwork", ports = ["443"] }
    "allow-apim-management"  = { priority = 110, direction = "Inbound", source = "ApiManagement", destination = "VirtualNetwork", ports = ["3443"] }
    "allow-load-balancer"    = { priority = 120, direction = "Inbound", source = "AzureLoadBalancer", destination = "VirtualNetwork", ports = ["6390"] }
    "allow-storage"          = { priority = 100, direction = "Outbound", source = "VirtualNetwork", destination = "Storage", ports = ["443"] }
    "allow-sql"              = { priority = 110, direction = "Outbound", source = "VirtualNetwork", destination = "Sql", ports = ["1433"] }
    "allow-key-vault"        = { priority = 120, direction = "Outbound", source = "VirtualNetwork", destination = "AzureKeyVault", ports = ["443"] }
    "allow-monitor"          = { priority = 130, direction = "Outbound", source = "VirtualNetwork", destination = "AzureMonitor", ports = ["443", "1886"] }
    "allow-entra"            = { priority = 140, direction = "Outbound", source = "VirtualNetwork", destination = "AzureActiveDirectory", ports = ["443"] }
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

resource "azurerm_api_management" "this" {
  count = local.apim

  # checkov:skip=CKV_AZURE_174:External mode on purpose: the runner is on the internet and every call needs an Entra token with the AI.Invoke role (ADR-0008).
  name                          = "${var.prefix}-apim-aiservices-prd-ae"
  resource_group_name           = local.rg
  location                      = local.location
  publisher_name                = "BinuForge lab"
  publisher_email               = var.apim_publisher_email
  sku_name                      = "Developer_1"
  virtual_network_type          = "External"
  public_ip_address_id          = azurerm_public_ip.apim[0].id
  public_network_access_enabled = true
  min_api_version               = "2021-08-01"
  tags                          = local.tags

  virtual_network_configuration {
    subnet_id = azurerm_subnet.this["apim"].id
  }

  identity {
    type = "SystemAssigned"
  }

  depends_on = [azurerm_network_security_rule.apim]
}

# The kill switch's value is changed by the runbook, in seconds, so Terraform deliberately leaves it alone.
resource "azurerm_api_management_named_value" "kill_switch" {
  count = local.apim

  name                = local.kill_switch_name
  display_name        = local.kill_switch_name
  resource_group_name = local.rg
  api_management_name = azurerm_api_management.this[0].name
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
  api_management_name   = azurerm_api_management.this[0].name
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
  api_management_name = azurerm_api_management.this[0].name
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
  api_management_name = azurerm_api_management.this[0].name
  resource_group_name = local.rg

  xml_content = templatefile("${path.module}/policies/ai-gateway.xml.tftpl", {
    tenant_id         = data.azurerm_client_config.current.tenant_id
    audience          = local.gateway_audience
    tokens_per_minute = var.gateway_tokens_per_minute
    kill_switch       = local.kill_switch_name
  })

  depends_on = [azurerm_api_management_named_value.kill_switch]
}

# The only data-plane role on Foundry (ADR-0008). Allowed by this level's role assignment condition.
resource "azurerm_role_assignment" "apim_openai_user" {
  count = local.apim

  scope                = azurerm_cognitive_account.this.id
  role_definition_name = "Cognitive Services OpenAI User"
  principal_id         = one(azurerm_api_management.this[0].identity).principal_id
  principal_type       = "ServicePrincipal"
  description          = "AI gateway, ADR-0008. The only caller allowed on the model."
}

resource "azurerm_monitor_diagnostic_setting" "apim_ops" {
  count = local.apim

  name                       = "${var.prefix}-diag-apim-ops"
  target_resource_id         = azurerm_api_management.this[0].id
  log_analytics_workspace_id = local.management.log_analytics_workspace_id

  enabled_log {
    category = "GatewayLogs"
  }

  enabled_metric {
    category = "AllMetrics"
  }
}
