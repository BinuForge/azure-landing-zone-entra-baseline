# Runs with mock providers: no sign-in, no network calls, nothing created.
mock_provider "azurerm" {
  mock_data "azurerm_resource_group" {
    defaults = {
      name     = "lab-rg-dns-prd-ae"
      location = "australiaeast"
    }
  }
}

mock_provider "tfe" {
  mock_data "tfe_outputs" {
    defaults = {
      nonsensitive_values = {
        hub_vnet_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/lab-rg-connectivity-prd-ae/providers/Microsoft.Network/virtualNetworks/lab-vnet-hub-prd-ae"
      }
    }
  }
}

run "foundry_private_endpoint_zones_exist" {
  command = plan

  assert {
    condition = toset([for z in azurerm_private_dns_zone.this : z.name]) == toset([
      "privatelink.cognitiveservices.azure.com",
      "privatelink.openai.azure.com",
      "privatelink.services.ai.azure.com",
    ])
    error_message = "All three Foundry private endpoint zones must exist."
  }
}

run "every_zone_links_to_the_hub_from_connectivity_outputs" {
  command = plan

  assert {
    condition     = alltrue([for l in azurerm_private_dns_zone_virtual_network_link.hub : endswith(l.virtual_network_id, "/virtualNetworks/lab-vnet-hub-prd-ae")])
    error_message = "Every zone must link to the hub VNet published by connectivity."
  }

  assert {
    condition     = alltrue([for l in azurerm_private_dns_zone_virtual_network_link.hub : l.registration_enabled == false])
    error_message = "Auto-registration must be off: records come only from private endpoints."
  }
}

run "dns_reads_connectivity_by_workspace_name" {
  command = plan

  assert {
    condition     = data.tfe_outputs.connectivity.workspace == "lab-azure-l2-connectivity-prd"
    error_message = "DNS must read the hub from connectivity's workspace, its declared dependency."
  }
}
