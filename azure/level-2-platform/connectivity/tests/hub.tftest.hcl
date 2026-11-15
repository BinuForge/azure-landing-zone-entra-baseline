# Runs with a mock provider: no sign-in, no network calls, nothing created.
mock_provider "azurerm" {
  mock_data "azurerm_resource_group" {
    defaults = {
      name     = "lab-rg-connectivity-prd-ae"
      location = "australiaeast"
    }
  }
}

run "hub_follows_naming_and_address_plan" {
  command = plan

  assert {
    condition     = azurerm_virtual_network.hub.name == "lab-vnet-hub-prd-ae"
    error_message = "The hub name must follow docs/naming.md."
  }

  assert {
    condition     = azurerm_virtual_network.hub.address_space == toset(["10.10.0.0/22"])
    error_message = "The hub must use 10.10.0.0/22 (docs/architecture/address-plan.md)."
  }
}

run "reserved_subnets_match_the_address_plan" {
  command = plan

  assert {
    condition     = azurerm_subnet.reserved["AzureFirewallSubnet"].address_prefixes == tolist(["10.10.0.0/26"])
    error_message = "AzureFirewallSubnet must be 10.10.0.0/26, the minimum size Azure Firewall needs."
  }

  assert {
    condition     = azurerm_subnet.reserved["GatewaySubnet"].address_prefixes == tolist(["10.10.0.64/27"])
    error_message = "GatewaySubnet must be 10.10.0.64/27."
  }

  assert {
    condition     = alltrue([for s in azurerm_subnet.reserved : s.default_outbound_access_enabled == false])
    error_message = "No subnet may have default outbound internet access."
  }
}

run "small_hub_is_rejected" {
  command = plan

  variables {
    hub_address_space = "10.10.0.0/24"
  }

  expect_failures = [var.hub_address_space]
}
