# Created by bootstrap, whose state is never shared, so looked up by name (ADR-0013).
data "azurerm_resource_group" "aiservices" {
  name = "${var.prefix}-rg-aiservices-prd-ae"
}

# Lower levels' published outputs (ADR-0013), from the reads list in tfc/workspaces.yaml.
data "tfe_outputs" "management" {
  workspace = "${var.prefix}-azure-l2-management-prd"
}

data "tfe_outputs" "connectivity" {
  workspace = "${var.prefix}-azure-l2-connectivity-prd"
}

data "tfe_outputs" "dns" {
  workspace = "${var.prefix}-azure-l2-dns-prd"
}

locals {
  location = data.azurerm_resource_group.aiservices.location
  rg       = data.azurerm_resource_group.aiservices.name

  management   = data.tfe_outputs.management.nonsensitive_values
  connectivity = data.tfe_outputs.connectivity.nonsensitive_values
  dns          = data.tfe_outputs.dns.nonsensitive_values

  tags = {
    managed-by = "${var.prefix}-azure-l3-aiservices-prd"
  }
}
