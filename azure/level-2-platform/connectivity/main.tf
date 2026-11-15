# Created by bootstrap, whose state is never shared, so looked up by name (ADR-0013).
data "azurerm_resource_group" "connectivity" {
  name = "${var.prefix}-rg-connectivity-prd-ae"
}

locals {
  # Subnets reserved now so the address plan is fixed in Azure, not just on paper. Azure requires these
  # names and minimum sizes, and allows no network security group on them. The services that use them
  # (firewall, VPN gateway) sit behind cost flags that are off.
  reserved_subnets = {
    AzureFirewallSubnet = cidrsubnet(var.hub_address_space, 4, 0) # 10.10.0.0/26
    GatewaySubnet       = cidrsubnet(var.hub_address_space, 5, 2) # 10.10.0.64/27
  }
}

# The hub every spoke peers with. No firewall, gateway or Bastion yet: each is a cost flag, off by default
# (docs/cost.md). Without a firewall, spokes cannot reach each other: peering is not transitive.
resource "azurerm_virtual_network" "hub" {
  name                = "${var.prefix}-vnet-hub-prd-ae"
  resource_group_name = data.azurerm_resource_group.connectivity.name
  location            = data.azurerm_resource_group.connectivity.location
  address_space       = [var.hub_address_space]

  tags = {
    managed-by = "${var.prefix}-azure-l2-connectivity-prd"
  }
}

resource "azurerm_subnet" "reserved" {
  for_each = local.reserved_subnets

  name                 = each.key
  resource_group_name  = data.azurerm_resource_group.connectivity.name
  virtual_network_name = azurerm_virtual_network.hub.name
  address_prefixes     = [each.value]

  # No outbound access by default for anything placed here later; services that need it say so.
  default_outbound_access_enabled = false
}
