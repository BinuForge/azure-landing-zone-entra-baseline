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
      role_definition_resource_id = "/subscriptions/00000000-0000-0000-0000-000000000000/providers/Microsoft.Authorization/roleDefinitions/00000000-0000-0000-0000-0000000000aa"
    }
  }
  mock_resource "azurerm_storage_account" {
    defaults = {
      id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/mock/providers/Microsoft.Storage/storageAccounts/mock"
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
  github_owner               = "example"
  github_apply_reviewer      = "example"
}

run "report_store_accepts_entra_identities_only" {
  command = plan

  assert {
    condition     = azurerm_storage_account.reports.shared_access_key_enabled == false && azurerm_storage_account.reports.local_user_enabled == false
    error_message = "The report store must refuse shared keys and local users (ADR-0015)."
  }

  assert {
    condition     = azurerm_storage_account.reports.allow_nested_items_to_be_public == false && azurerm_storage_container.reports.container_access_type == "private"
    error_message = "Nothing in the report store may be anonymous."
  }

  assert {
    condition     = one(azurerm_storage_account.reports.blob_properties).versioning_enabled && one(one(azurerm_storage_account.reports.blob_properties).delete_retention_policy).days >= 30
    error_message = "Versioning and soft delete keep every report recoverable."
  }

  assert {
    condition     = azurerm_resource_group.this["bootstrap"].name == azurerm_storage_account.reports.resource_group_name
    error_message = "The report store must sit in the locked bootstrap group, so it outlives teardowns."
  }
}

run "runner_can_only_add_reports" {
  command = plan

  assert {
    condition = toset(one(azurerm_role_definition.report_writer.permissions).data_actions) == toset([
      "Microsoft.Storage/storageAccounts/blobServices/containers/blobs/write",
      "Microsoft.Storage/storageAccounts/blobServices/containers/blobs/add/action",
    ])
    error_message = "The report writer may add blobs only: no read, list or delete."
  }

  assert {
    condition     = length(coalesce(one(azurerm_role_definition.report_writer.permissions).actions, [])) == 0
    error_message = "The report writer needs no control-plane actions."
  }

  assert {
    condition     = azurerm_role_assignment.pipeline["azure-l4-opsagent-run/report-writer/reports"].principal_type == "ServicePrincipal" && azurerm_role_assignment.report_reader.principal_type == "User"
    error_message = "The runner writes; only the maintainer reads."
  }
}

run "unique_suffix_reaches_the_storage_name_only" {
  command = plan

  variables {
    unique_suffix = "x7k"
  }

  assert {
    condition     = azurerm_storage_account.reports.name == "labstreportsprdae01x7k"
    error_message = "The report store name must end with the unique suffix (docs/naming.md)."
  }

  assert {
    condition     = azurerm_resource_group.this["bootstrap"].name == "lab-rg-bootstrap-prd-ae"
    error_message = "Names that are unique only inside the subscription must not take the suffix."
  }
}

run "original_lab_names_are_unchanged" {
  command = plan

  assert {
    condition     = azurerm_storage_account.reports.name == "labstreportsprdae01"
    error_message = "With no suffix, the report store keeps its original name, so the original lab plans no change."
  }
}
