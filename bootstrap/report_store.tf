# The ops agent's report store (threat model C-12, ADR-0015). In the locked bootstrap group, so reports
# outlive every teardown. Only Entra identities with a data role get in: shared keys, and with them
# account and service SAS, are off, and nothing is anonymous.
locals {
  report_store_name = "${var.prefix}streportsprd${local.region}01"
}

resource "azurerm_storage_account" "reports" {
  # checkov:skip=CKV_AZURE_59:Public endpoint on purpose: GitHub-hosted runners are on the internet. Access needs an Entra data role (ADR-0015).
  # checkov:skip=CKV_AZURE_35:Network rules would block the runner for the same reason; identity is the boundary (ADR-0015).
  # checkov:skip=CKV2_AZURE_33:No private endpoint for the same reason. Bank target: private endpoint and self-hosted runners (ADR-0015).
  # checkov:skip=CKV2_AZURE_1:Microsoft-managed keys, by data classification (ADR-0014).
  # checkov:skip=CKV_AZURE_33:No queues are used, and queue logging needs the data plane, which Terraform does not use here.
  # checkov:skip=CKV_AZURE_43:The name is built from variables, which the scanner cannot resolve; the precondition below checks the rule.
  # checkov:skip=CKV2_AZURE_21:Blob logs would go to the ops workspace, which is torn down with level 2. Bank target: storage logs to the SIEM.
  name                              = local.report_store_name
  resource_group_name               = azurerm_resource_group.this["bootstrap"].name
  location                          = var.location
  account_kind                      = "StorageV2"
  account_tier                      = "Standard"
  account_replication_type          = "GZRS" # the reports are the record, so they survive a zone or region outage
  min_tls_version                   = "TLS1_2"
  https_traffic_only_enabled        = true
  shared_access_key_enabled         = false
  default_to_oauth_authentication   = true
  allow_nested_items_to_be_public   = false
  public_network_access_enabled     = true
  local_user_enabled                = false
  cross_tenant_replication_enabled  = false
  infrastructure_encryption_enabled = true

  blob_properties {
    # An overwrite keeps the old version, and the writer role cannot delete versions.
    versioning_enabled = true

    delete_retention_policy {
      days = 30
    }

    container_delete_retention_policy {
      days = 30
    }
  }

  # A user delegation SAS needs an Entra identity with a data role; any such link expires within an hour.
  sas_policy {
    expiration_period = "00.01:00:00"
  }

  tags = {
    managed-by = "${var.prefix}-${local.resource_groups.bootstrap.workspace}"
    used-by    = "${var.prefix}-${local.resource_groups.opsagent.workspace}"
  }

  lifecycle {
    # The reports are the record (ADR-0015). A second guard after the resource group lock.
    prevent_destroy = true

    precondition {
      condition     = can(regex("^[a-z0-9]{3,24}$", local.report_store_name))
      error_message = "Storage account names are 3 to 24 lowercase letters and digits (docs/naming.md)."
    }
  }
}

resource "azurerm_storage_container" "reports" {
  # checkov:skip=CKV2_AZURE_21:Blob logs would go to the ops workspace, which is torn down with level 2. Bank target: storage logs to the SIEM.
  name                  = "reports"
  storage_account_id    = azurerm_storage_account.reports.id
  container_access_type = "private"

  lifecycle {
    prevent_destroy = true
  }
}

# Write-only (ADR-0015): the runner can add a report, but cannot read, list or delete one.
resource "azurerm_role_definition" "report_writer" {
  name        = "${var.prefix}-role-report-writer"
  scope       = local.subscription_scope
  description = "Add blobs to the ops agent's report store. No read, list or delete. Created by bootstrap, ADR-0015."

  permissions {
    data_actions = [
      "Microsoft.Storage/storageAccounts/blobServices/containers/blobs/write",
      "Microsoft.Storage/storageAccounts/blobServices/containers/blobs/add/action",
    ]
  }

  assignable_scopes = [azurerm_resource_group.this["bootstrap"].id]
}

resource "azurerm_role_assignment" "report_writer" {
  scope              = azurerm_storage_container.reports.id
  principal_id       = azuread_service_principal.pipeline["azure-l4-opsagent-run"].object_id
  principal_type     = "ServicePrincipal"
  role_definition_id = azurerm_role_definition.report_writer.role_definition_resource_id
  description        = "Ops agent runner adds reports, ADR-0015."
}

# Only the maintainer reads reports. At a bank: a PIM-eligible group (ADR-0012, risks accepted).
resource "azurerm_role_assignment" "report_reader" {
  scope                = azurerm_storage_container.reports.id
  principal_id         = data.azuread_client_config.current.object_id
  principal_type       = "User"
  role_definition_name = "Storage Blob Data Reader"
  description          = "Maintainer reads ops agent reports, ADR-0015."
}
