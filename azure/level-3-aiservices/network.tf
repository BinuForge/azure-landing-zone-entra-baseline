locals {
  # Two ranges overlap exactly when they share a network address at the shorter of their prefixes.
  shorter_prefix = min(tonumber(split("/", var.spoke_address_space)[1]), tonumber(split("/", local.connectivity.hub_address_space)[1]))
  overlaps_hub = (
    cidrhost("${cidrhost(var.spoke_address_space, 0)}/${local.shorter_prefix}", 0) ==
    cidrhost("${cidrhost(local.connectivity.hub_address_space, 0)}/${local.shorter_prefix}", 0)
  )

  subnets = {
    privateendpoints = cidrsubnet(var.spoke_address_space, 3, 0) # 10.20.0.0/27
    apim             = cidrsubnet(var.spoke_address_space, 3, 2) # 10.20.0.64/27, used when APIM is enabled
  }
}

resource "azurerm_virtual_network" "spoke" {
  name                = "${var.prefix}-vnet-aiservices-prd-ae"
  resource_group_name = local.rg
  location            = local.location
  address_space       = [var.spoke_address_space]
  tags                = local.tags

  lifecycle {
    precondition {
      condition     = !local.overlaps_hub
      error_message = "The spoke range overlaps the hub; peering would be refused (docs/architecture/address-plan.md)."
    }
  }
}

resource "azurerm_network_security_group" "this" {
  for_each = local.subnets

  name                = "${var.prefix}-nsg-${each.key}-prd-ae"
  resource_group_name = local.rg
  location            = local.location
  tags                = local.tags
}

resource "azurerm_subnet" "this" {
  for_each = local.subnets

  name                            = "${var.prefix}-snet-${each.key}-prd-ae"
  resource_group_name             = local.rg
  virtual_network_name            = azurerm_virtual_network.spoke.name
  address_prefixes                = [each.value]
  default_outbound_access_enabled = false

  # Network security groups apply to private endpoints in this subnet too.
  private_endpoint_network_policies = each.key == "privateendpoints" ? "Enabled" : "Disabled"
}

resource "azurerm_subnet_network_security_group_association" "this" {
  for_each = local.subnets

  subnet_id                 = azurerm_subnet.this[each.key].id
  network_security_group_id = azurerm_network_security_group.this[each.key].id
}

# Both sides of the peering. The hub side sits in connectivity's group, which this level can only
# peer into, through lab-role-spoke-network-join (ADR-0012).
resource "azurerm_virtual_network_peering" "spoke_to_hub" {
  name                      = "${var.prefix}-peer-aiservices-to-hub"
  resource_group_name       = local.rg
  virtual_network_name      = azurerm_virtual_network.spoke.name
  remote_virtual_network_id = local.connectivity.hub_vnet_id
  allow_forwarded_traffic   = false
  allow_gateway_transit     = false
  use_remote_gateways       = false
}

resource "azurerm_virtual_network_peering" "hub_to_spoke" {
  name                      = "${var.prefix}-peer-hub-to-aiservices"
  resource_group_name       = local.connectivity.resource_group_name
  virtual_network_name      = local.connectivity.hub_vnet_name
  remote_virtual_network_id = azurerm_virtual_network.spoke.id
  allow_forwarded_traffic   = false
  allow_gateway_transit     = false
  use_remote_gateways       = false
}

# The spoke resolves private endpoints through the central zones, never zones of its own.
resource "azurerm_private_dns_zone_virtual_network_link" "spoke" {
  for_each = local.dns.private_dns_zone_ids

  name                  = "${var.prefix}-link-aiservices-${each.key}"
  resource_group_name   = local.dns.resource_group_name
  private_dns_zone_name = element(split("/", each.value), length(split("/", each.value)) - 1)
  virtual_network_id    = azurerm_virtual_network.spoke.id
  registration_enabled  = false
  tags                  = local.tags
}
