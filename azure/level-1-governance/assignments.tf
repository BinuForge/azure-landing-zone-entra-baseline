# Assignment names are at most 24 characters at management group scope.

resource "azurerm_management_group_policy_assignment" "baseline" {
  name                 = "${var.prefix}-baseline"
  display_name         = "Lab platform baseline v1"
  management_group_id  = local.mg.root
  policy_definition_id = azurerm_management_group_policy_set_definition.baseline.id

  parameters = jsonencode({ allowedLocations = { value = var.allowed_locations } })

  non_compliance_message {
    content = "Lab resources must be in Australia East or Australia Southeast (docs/naming.md)."
  }
}

resource "azurerm_management_group_policy_assignment" "ai" {
  name                 = "${var.prefix}-ai-baseline"
  display_name         = "Lab AI services baseline v1"
  management_group_id  = local.mg.landingzones
  policy_definition_id = azurerm_management_group_policy_set_definition.ai.id

  parameters = jsonencode({ approvedModelAssetIds = { value = var.approved_model_asset_ids } })

  non_compliance_message {
    content = "AI services must be private, keyless, AIServices kind, and deploy only approved, generally available models (ADR-0008, threat-model-ai.md)."
  }
}

resource "azurerm_management_group_policy_assignment" "corp_no_public_ip" {
  name                 = "${var.prefix}-corp-no-pip"
  display_name         = "Corp: no public IP addresses"
  management_group_id  = local.mg.corp
  policy_definition_id = "/providers/Microsoft.Authorization/policyDefinitions/${local.builtin.not_allowed_types}"

  parameters = jsonencode({
    effect                        = { value = "Deny" }
    listOfResourceTypesNotAllowed = { value = ["Microsoft.Network/publicIPAddresses"] }
  })

  non_compliance_message {
    content = "Corp workloads are private. A public IP needs a scoped, expiring exemption in level 1."
  }
}

# Audit only: Microsoft's view of compliance across the lab, used for the MCSB mapping.
resource "azurerm_management_group_policy_assignment" "mcsb" {
  name                 = "${var.prefix}-mcsb"
  display_name         = "Microsoft cloud security benchmark"
  management_group_id  = local.mg.root
  policy_definition_id = "/providers/Microsoft.Authorization/policySetDefinitions/${local.builtin.mcsb}"
  enforce              = false
}

# Hands-on study needs the portal's defaults, such as public access and keys. The waiver is scoped to one
# group, names its reason, and expires; renewing it is a pull request.
resource "azurerm_resource_group_policy_exemption" "study" {
  for_each = {
    ai     = azurerm_management_group_policy_assignment.ai.id
    no-pip = azurerm_management_group_policy_assignment.corp_no_public_ip.id
  }

  name                 = "${var.prefix}-study-${each.key}"
  display_name         = "Study sandbox waiver: ${each.key}"
  resource_group_id    = data.azurerm_resource_group.study.id
  policy_assignment_id = each.value
  exemption_category   = "Waiver"
  expires_on           = var.study_exemption_expires_on
  description          = "Hands-on study in lab-rg-study-np-ae. Reported by the leftovers check; renew by pull request."

  lifecycle {
    precondition {
      condition     = timecmp(var.study_exemption_expires_on, timeadd(plantimestamp(), "720h")) <= 0
      error_message = "The study waiver may run at most 30 days from today. Choose an earlier expiry."
    }
  }
}
