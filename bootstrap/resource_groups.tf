locals {
  # Resource providers the lab uses. Add one here, in its own PR, before a level needs it.
  resource_providers = [
    "Microsoft.Advisor",
    "Microsoft.AlertsManagement",
    "Microsoft.ApiManagement",
    "Microsoft.CognitiveServices",
    "Microsoft.Consumption",
    "Microsoft.CostManagement",
    "Microsoft.Insights",
    "Microsoft.Management",
    "Microsoft.ManagedIdentity",
    "Microsoft.Network",
    "Microsoft.OperationalInsights",
    "Microsoft.PolicyInsights",
    "Microsoft.ResourceGraph",
    "Microsoft.Security",
    "Microsoft.Storage",
  ]

  region_codes = {
    australiaeast      = "ae"
    australiasoutheast = "ase"
    southeastasia      = "se"
    eastasia           = "ea"
  }
  region = local.region_codes[var.location]

  # One resource group per level component. Each level's apply identity is scoped to its own groups
  # (ADR-0012), so these groups are the boundary between levels in the single subscription (ADR-0004).
  resource_groups = {
    bootstrap    = { env = "prd", workspace = "tfc-l0-bootstrap-prd" }
    management   = { env = "prd", workspace = "azure-l2-management-prd" }
    connectivity = { env = "prd", workspace = "azure-l2-connectivity-prd" }
    dns          = { env = "prd", workspace = "azure-l2-dns-prd" }
    aiservices   = { env = "prd", workspace = "azure-l3-aiservices-prd" }
    opsagent     = { env = "np", workspace = "azure-l4-opsagent-np" }
    # Hands-on study and portal experiments. Level 1 gives it a time-boxed exemption from Deny policies,
    # and the leftovers check reports what is in it without failing.
    study = { env = "np", workspace = "study" }
  }
}

# The provider-level list above left Microsoft.Insights unregistered (checked with `az provider show` on
# 2026-11-15, after several bootstrap runs), which blocked every diagnostic setting. Managed explicitly,
# so it is in state and in the plan.
resource "azurerm_resource_provider_registration" "insights" {
  name = "Microsoft.Insights"
}

resource "azurerm_resource_group" "this" {
  for_each = local.resource_groups

  name     = "${var.prefix}-rg-${each.key}-${each.value.env}-${local.region}"
  location = var.location

  tags = {
    managed-by = "${var.prefix}-${local.resource_groups.bootstrap.workspace}"
    used-by    = "${var.prefix}-${each.value.workspace}"
  }
}

# Bootstrap's own group holds what must outlive every teardown, such as the report store (threat model
# C-12). Level groups are not locked: a lock on a group also blocks deleting the resources in it, which
# would stop the destroy workflow.
resource "azurerm_management_lock" "bootstrap" {
  name       = "${var.prefix}-lock-bootstrap"
  scope      = azurerm_resource_group.this["bootstrap"].id
  lock_level = "CanNotDelete"
  notes      = "Holds resources that must survive teardowns. Remove only by changing bootstrap."
}
