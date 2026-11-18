data "azurerm_client_config" "current" {}

# Created by bootstrap, whose state is never shared, so looked up by name (ADR-0013).
data "azurerm_resource_group" "this" {
  for_each = local.groups

  name = each.value
}

# The ops workspace, from level 2's published outputs (ADR-0013).
data "tfe_outputs" "management" {
  workspace = "${var.prefix}-azure-l2-management-prd"
}

locals {
  # The groups the runner may read. Not AI services: the prompt workspace lives there (threat model C-06,
  # design decision D1). AI costs still reach the runner through Cost Management.
  groups = {
    management   = "${var.prefix}-rg-management-prd-ae"
    connectivity = "${var.prefix}-rg-connectivity-prd-ae"
    dns          = "${var.prefix}-rg-dns-prd-ae"
    opsagent     = "${var.prefix}-rg-opsagent-np-ae"
  }

  management   = data.tfe_outputs.management.nonsensitive_values
  subscription = "/subscriptions/${data.azurerm_client_config.current.subscription_id}"

  tags = {
    managed-by = "${var.prefix}-azure-l4-opsagent-np"
  }
}
