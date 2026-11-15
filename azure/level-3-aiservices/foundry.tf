# The shared AI services account (ADR-0007). No public path and no keys: the only way in is the private
# endpoint, with an Entra token that holds a data-plane role (ADR-0008). Level 1 policy denies both,
# so this is enforced twice.
resource "azurerm_cognitive_account" "this" {
  name                          = "${var.prefix}-ais-aiservices-prd-ae"
  resource_group_name           = local.rg
  location                      = local.location
  kind                          = "AIServices"
  sku_name                      = "S0"
  custom_subdomain_name         = "${var.prefix}-ais-aiservices-prd-ae"
  project_management_enabled    = true
  public_network_access_enabled = false
  local_auth_enabled            = false
  tags                          = local.tags

  network_acls {
    default_action = "Deny"
    bypass         = "None"
  }

  identity {
    type = "SystemAssigned"
  }
}

# One project per consumer. The ops agent is the first (threat-model-ai.md).
resource "azurerm_cognitive_account_project" "opsagent" {
  name                 = "opsagent"
  display_name         = "Ops agent"
  description          = "Read-only infrastructure agent. Consumer of the AI services landing zone."
  cognitive_account_id = azurerm_cognitive_account.this.id
  location             = local.location
  tags                 = local.tags

  identity {
    type = "SystemAssigned"
  }
}

resource "azurerm_private_endpoint" "foundry" {
  name                = "${var.prefix}-pe-aiservices-prd-ae"
  resource_group_name = local.rg
  location            = local.location
  subnet_id           = azurerm_subnet.this["privateendpoints"].id
  tags                = local.tags

  private_service_connection {
    name                           = "${var.prefix}-psc-aiservices"
    private_connection_resource_id = azurerm_cognitive_account.this.id
    subresource_names              = ["account"]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name                 = "foundry"
    private_dns_zone_ids = values(local.dns.private_dns_zone_ids)
  }
}

locals {
  # Stricter than Microsoft.DefaultV2: harm categories block from Low on both prompt and completion,
  # Prompt Shields block jailbreaks and indirect attacks (threat model C-02), and protected material is
  # blocked on output. Ops agent prompts are infrastructure data, so strict filtering costs nothing.
  harm_filters = flatten([
    for name in ["Hate", "Sexual", "Violence", "SelfHarm"] : [
      for source in ["Prompt", "Completion"] : { name = name, source = source, severity = "Low" }
    ]
  ])
  shield_filters = [
    { name = "Jailbreak", source = "Prompt", severity = "High" },
    { name = "Indirect Attack", source = "Prompt", severity = "High" },
    { name = "Protected Material Text", source = "Completion", severity = "High" },
    { name = "Protected Material Code", source = "Completion", severity = "High" },
  ]
}

resource "azurerm_cognitive_account_rai_policy" "strict" {
  name                 = "${var.prefix}-rai-strict-v1"
  cognitive_account_id = azurerm_cognitive_account.this.id
  base_policy_name     = "Microsoft.DefaultV2"

  dynamic "content_filter" {
    for_each = concat(local.harm_filters, local.shield_filters)
    content {
      name               = content_filter.value.name
      source             = content_filter.value.source
      severity_threshold = content_filter.value.severity
      filter_enabled     = true
      block_enabled      = true
    }
  }
}

# Global Standard is the only chat deployment type with quota on this subscription (ADR-0009).
resource "azurerm_cognitive_deployment" "this" {
  for_each = var.model_deployments

  name                   = each.key
  cognitive_account_id   = azurerm_cognitive_account.this.id
  rai_policy_name        = azurerm_cognitive_account_rai_policy.strict.name
  version_upgrade_option = "NoAutoUpgrade"

  model {
    format  = "OpenAI"
    name    = each.value.model_name
    version = each.value.model_version
  }

  sku {
    name     = "GlobalStandard"
    capacity = each.value.capacity
  }
}
