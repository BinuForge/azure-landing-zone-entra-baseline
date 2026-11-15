# Created by bootstrap, whose state is never shared, so looked up by name (ADR-0013).
data "azurerm_resource_group" "dns" {
  name = "${var.prefix}-rg-dns-prd-ae"
}

# The hub, from connectivity's published outputs (ADR-0013).
data "tfe_outputs" "connectivity" {
  workspace = "${var.prefix}-azure-l2-connectivity-prd"
}

locals {
  hub_vnet_id = data.tfe_outputs.connectivity.nonsensitive_values.hub_vnet_id

  # The private endpoint zones a Foundry account needs. One central copy of each, linked to the hub, so
  # every spoke resolves private endpoints the same way. Zone names are fixed by Azure.
  zones = {
    cognitiveservices = "privatelink.cognitiveservices.azure.com"
    openai            = "privatelink.openai.azure.com"
    aiservices        = "privatelink.services.ai.azure.com"
  }
}

resource "azurerm_private_dns_zone" "this" {
  for_each = local.zones

  name                = each.value
  resource_group_name = data.azurerm_resource_group.dns.name

  tags = {
    managed-by = "${var.prefix}-azure-l2-dns-prd"
  }
}

resource "azurerm_private_dns_zone_virtual_network_link" "hub" {
  for_each = local.zones

  name                  = "${var.prefix}-link-hub-${each.key}"
  resource_group_name   = data.azurerm_resource_group.dns.name
  private_dns_zone_name = azurerm_private_dns_zone.this[each.key].name
  virtual_network_id    = local.hub_vnet_id

  # Records come only from private endpoints, never from machines registering themselves.
  registration_enabled = false

  tags = {
    managed-by = "${var.prefix}-azure-l2-dns-prd"
  }
}
