# Runs with mock providers: no sign-in, no network calls, nothing created.
mock_provider "azurerm" {
  override_during = plan

  mock_resource "azurerm_resource_group" {
    defaults = {
      id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/mock"
    }
  }
  mock_resource "azurerm_role_definition" {
    defaults = {
      role_definition_resource_id = "/providers/Microsoft.Authorization/roleDefinitions/00000000-0000-0000-0000-0000000000aa"
    }
  }
}

mock_provider "azuread" {
  mock_data "azuread_client_config" {
    defaults = {
      object_id = "00000000-0000-0000-0000-000000000001"
      tenant_id = "00000000-0000-0000-0000-000000000002"
    }
  }
}

mock_provider "github" {
  mock_data "github_user" {
    defaults = {
      id = "12345"
    }
  }
}

mock_provider "azapi" {
  # What Azure stores for the default management group: its short name (governance.tf check).
  mock_data "azapi_resource" {
    defaults = {
      output = { properties = { defaultManagementGroup = "lab-mg-sandbox" } }
    }
  }
}

variables {
  subscription_id            = "00000000-0000-0000-0000-000000000000"
  budget_contact_emails      = ["alerts@example.com"]
  github_oidc_subject_prefix = "repo:example@1/repo@2"
  hcp_organization           = "example-org"
}

run "subscription_is_placed_in_corp" {
  command = plan

  assert {
    condition     = azurerm_management_group_subscription_association.corp.management_group_id == "/providers/Microsoft.Management/managementGroups/lab-mg-corp"
    error_message = "The lab subscription must sit in lab-mg-corp, so the strictest workload policy applies (ADR-0004)."
  }
}

run "new_subscriptions_land_in_sandbox_and_group_creation_needs_rights" {
  command = plan

  assert {
    condition     = azapi_resource.hierarchy_settings.body.properties.defaultManagementGroup == "/providers/Microsoft.Management/managementGroups/lab-mg-sandbox"
    error_message = "New subscriptions must land in sandbox, not the tenant root."
  }

  assert {
    condition     = azapi_resource.hierarchy_settings.body.properties.requireAuthorizationForGroupCreation == true
    error_message = "Creating a management group must need write rights at the root."
  }
}

run "maintainer_writes_only_where_bootstrap_needs_to" {
  command = plan

  assert {
    condition     = azurerm_role_assignment.maintainer["mg-reader/root"].role_definition_name == "Management Group Reader"
    error_message = "The maintainer's access to the hierarchy must be read-only."
  }

  assert {
    condition     = azurerm_role_assignment.maintainer["mg-contributor/corp"].scope == "/providers/Microsoft.Management/managementGroups/lab-mg-corp"
    error_message = "The maintainer's write access must be limited to lab-mg-corp."
  }

  assert {
    condition     = alltrue([for ra in azurerm_role_assignment.maintainer : !contains(["Owner", "User Access Administrator", "Contributor"], ra.role_definition_name)])
    error_message = "The maintainer must not get a standing broad role."
  }
}

run "hierarchy_settings_role_has_exactly_two_actions" {
  command = plan

  assert {
    condition = toset(one(azurerm_role_definition.hierarchy_settings.permissions).actions) == toset([
      "Microsoft.Management/managementgroups/settings/read",
      "Microsoft.Management/managementgroups/settings/write",
    ])
    error_message = "The hierarchy settings role must grant only the two documented actions."
  }
}
