# Runs with a mock provider: no sign-in, no network calls, nothing created.
mock_provider "azurerm" {
  override_during = plan

  mock_data "azurerm_client_config" {
    defaults = {
      tenant_id = "00000000-0000-0000-0000-000000000001"
    }
  }

  mock_resource "azurerm_management_group" {
    defaults = {
      id = "/providers/Microsoft.Management/managementGroups/mock"
    }
  }
}

# Distinct IDs for the parents, so a group wired to the wrong parent fails the tests below.
override_resource {
  target          = azurerm_management_group.root
  override_during = plan
  values = {
    id = "/providers/Microsoft.Management/managementGroups/lab-mg-root"
  }
}

override_resource {
  target          = azurerm_management_group.tier_2["landingzones"]
  override_during = plan
  values = {
    id = "/providers/Microsoft.Management/managementGroups/lab-mg-landingzones"
  }
}

run "intermediate_root_sits_under_the_tenant_root" {
  command = plan

  assert {
    condition     = azurerm_management_group.root.parent_management_group_id == "/providers/Microsoft.Management/managementGroups/00000000-0000-0000-0000-000000000001"
    error_message = "The intermediate root must sit directly under the tenant root group."
  }
}

run "hierarchy_has_ten_groups_following_naming" {
  command = plan

  assert {
    condition     = length(output.management_group_ids) == 10
    error_message = "Expected the intermediate root, four second-tier and five third-tier groups."
  }

  assert {
    condition = alltrue([
      for name in concat(
        [azurerm_management_group.root.name],
        [for mg in azurerm_management_group.tier_2 : mg.name],
        [for mg in azurerm_management_group.tier_3 : mg.name],
      ) : can(regex("^lab-mg-[a-z]+$", name))
    ])
    error_message = "A management group name does not follow docs/naming.md."
  }
}

run "nothing_is_created_directly_under_the_tenant_root" {
  command = plan

  assert {
    condition     = alltrue([for mg in azurerm_management_group.tier_2 : mg.parent_management_group_id == azurerm_management_group.root.id])
    error_message = "Second-tier groups must sit under the intermediate root, never the tenant root."
  }
}

run "corp_sits_under_landing_zones" {
  command = plan

  assert {
    condition     = azurerm_management_group.tier_3["corp"].parent_management_group_id == azurerm_management_group.tier_2["landingzones"].id
    error_message = "Corp, where the subscription is placed, must sit under Landing zones."
  }
}
