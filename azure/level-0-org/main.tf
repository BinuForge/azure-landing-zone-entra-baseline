data "azurerm_client_config" "current" {}

locals {
  tenant_root_id = "/providers/Microsoft.Management/managementGroups/${data.azurerm_client_config.current.tenant_id}"

  # Azure Landing Zone layout. Empty groups cost nothing and show the full design; the one subscription
  # is placed in corp by bootstrap, because moving a subscription needs Owner (ADR-0012).
  tier_2 = {
    platform       = "Platform"
    landingzones   = "Landing zones"
    sandbox        = "Sandbox"
    decommissioned = "Decommissioned"
  }

  tier_3 = {
    management   = { display_name = "Management", parent = "platform" }
    connectivity = { display_name = "Connectivity", parent = "platform" }
    identity     = { display_name = "Identity", parent = "platform" }
    corp         = { display_name = "Corp", parent = "landingzones" }
    online       = { display_name = "Online", parent = "landingzones" }
  }
}

# Intermediate root: everything the lab governs sits under this, never directly under the tenant root,
# so tenant-wide defaults stay untouched and the whole lab can be moved or removed as one.
resource "azurerm_management_group" "root" {
  name                       = "${var.prefix}-mg-root"
  display_name               = "Lab"
  parent_management_group_id = local.tenant_root_id
}

resource "azurerm_management_group" "tier_2" {
  for_each = local.tier_2

  name                       = "${var.prefix}-mg-${each.key}"
  display_name               = each.value
  parent_management_group_id = azurerm_management_group.root.id
}

resource "azurerm_management_group" "tier_3" {
  for_each = local.tier_3

  name                       = "${var.prefix}-mg-${each.key}"
  display_name               = each.value.display_name
  parent_management_group_id = azurerm_management_group.tier_2[each.value.parent].id
}
