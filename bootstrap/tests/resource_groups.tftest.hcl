# Runs with a mock provider: no Azure login, no network calls, nothing created.
mock_provider "azurerm" {
  # The lock's scope must look like a resource ID.
  mock_resource "azurerm_resource_group" {
    defaults = {
      id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/mock"
    }
  }
}

mock_provider "azuread" {
  mock_data "azuread_client_config" {
    defaults = {
      object_id = "00000000-0000-0000-0000-000000000001"
    }
  }
}

variables {
  subscription_id            = "00000000-0000-0000-0000-000000000000"
  budget_contact_emails      = ["alerts@example.com"]
  github_oidc_subject_prefix = "repo:example@1/repo@2"
  hcp_organization           = "example-org"
}

run "resource_group_names_follow_convention" {
  command = plan

  assert {
    condition     = alltrue([for rg in azurerm_resource_group.this : can(regex("^lab-rg-[a-z]+-(prd|np)-(ae|ase|se|ea)$", rg.name))])
    error_message = "A resource group name does not follow docs/naming.md."
  }

  assert {
    condition     = azurerm_resource_group.this["aiservices"].name == "lab-rg-aiservices-prd-ae"
    error_message = "The AI services group must be lab-rg-aiservices-prd-ae."
  }
}

run "every_group_records_its_owner_and_user" {
  command = plan

  assert {
    condition     = alltrue([for rg in azurerm_resource_group.this : rg.tags["managed-by"] == "lab-tfc-l0-bootstrap-prd" && startswith(rg.tags["used-by"], "lab-")])
    error_message = "Every group must be tagged with the workspace that manages it and the one that uses it."
  }
}

run "only_the_bootstrap_group_is_locked" {
  command = plan

  assert {
    condition     = azurerm_management_lock.bootstrap.lock_level == "CanNotDelete"
    error_message = "The bootstrap group must be protected from deletion."
  }
}

run "providers_cover_the_ai_landing_zone" {
  command = plan

  assert {
    condition     = alltrue([for p in ["Microsoft.CognitiveServices", "Microsoft.ApiManagement", "Microsoft.Network", "Microsoft.OperationalInsights"] : contains(output.resource_providers, p)])
    error_message = "Providers needed by the AI services landing zone are missing."
  }
}

run "unknown_region_is_rejected" {
  command = plan

  variables {
    location = "westeurope"
  }

  expect_failures = [var.location]
}
