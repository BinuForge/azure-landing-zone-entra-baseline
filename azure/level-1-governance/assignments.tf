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

resource "azurerm_management_group_policy_assignment" "ai_account" {
  name                 = "${var.prefix}-ai-account"
  display_name         = "Lab AI services account baseline v1"
  management_group_id  = local.mg.landingzones
  policy_definition_id = azurerm_management_group_policy_set_definition.ai_account.id

  non_compliance_message {
    content = "AI services accounts must be private, keyless and logged (ADR-0008, threat-model-ai.md)."
  }
}

resource "azurerm_management_group_policy_assignment" "ai_deployments" {
  name                 = "${var.prefix}-ai-deployments"
  display_name         = "Lab AI model deployment baseline v1"
  management_group_id  = local.mg.landingzones
  policy_definition_id = azurerm_management_group_policy_set_definition.ai_deployments.id

  parameters = jsonencode({ approvedModelAssetIds = { value = var.approved_model_asset_ids } })

  non_compliance_message {
    content = "Only approved, generally available, Microsoft-sold models may be deployed (threat-model-ai.md C-24)."
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

# Audit only: Microsoft's view of compliance across everything under the lab root, used for the MCSB
# mapping. Defender for Cloud also assigns it to the subscription by default, outside code; this one covers
# any future subscription too.
#
# Azure requires a managed identity because some of its policies are DeployIfNotExists. The identity is
# given no roles, so it cannot remediate anything.
resource "azurerm_management_group_policy_assignment" "mcsb" {
  name                 = "${var.prefix}-mcsb"
  display_name         = "Microsoft cloud security benchmark"
  management_group_id  = local.mg.root
  policy_definition_id = "/providers/Microsoft.Authorization/policySetDefinitions/${local.builtin.mcsb}"
  enforce              = false
  location             = var.allowed_locations[0]

  identity {
    type = "SystemAssigned"
  }
}

# Hands-on study needs the portal's defaults, such as public access and keys. The waiver is scoped to one
# group, names its reason, and expires; renewing it is a pull request.
resource "azurerm_resource_group_policy_exemption" "study" {
  for_each = {
    ai-account     = azurerm_management_group_policy_assignment.ai_account.id
    ai-deployments = azurerm_management_group_policy_assignment.ai_deployments.id
    no-pip         = azurerm_management_group_policy_assignment.corp_no_public_ip.id
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
