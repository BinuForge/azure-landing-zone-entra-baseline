# Deny where Microsoft's policy is generally available; Audit where it is preview, because a preview policy
# that denies can break deployments when Microsoft changes it.
resource "azurerm_management_group_policy_set_definition" "ai" {
  name                = "${var.prefix}-ini-ai-baseline-v1"
  display_name        = "Lab AI services baseline v1"
  description         = "Private, keyless Foundry with approved models and guardrails (threat-model-ai.md, ADR-0008)."
  policy_type         = "Custom"
  management_group_id = local.mg.root

  parameters = jsonencode({
    approvedModelAssetIds = { type = "Array", metadata = { displayName = "Approved model asset IDs" } }
  })

  policy_definition_reference {
    reference_id         = "restrictNetworkAccess"
    policy_definition_id = "/providers/Microsoft.Authorization/policyDefinitions/${local.builtin.ai_restrict_network}"
    parameter_values     = jsonencode({ effect = { value = "Deny" } })
  }

  policy_definition_reference {
    reference_id         = "disableLocalAuth"
    policy_definition_id = "/providers/Microsoft.Authorization/policyDefinitions/${local.builtin.ai_disable_local_auth}"
    parameter_values     = jsonencode({ effect = { value = "Deny" } })
  }

  policy_definition_reference {
    reference_id         = "allowedKinds"
    policy_definition_id = "/providers/Microsoft.Authorization/policyDefinitions/${local.builtin.ai_allowed_kinds}"
    parameter_values     = jsonencode({ allowedKinds = { value = ["AIServices"] } })
  }

  policy_definition_reference {
    reference_id         = "approvedModels"
    policy_definition_id = "/providers/Microsoft.Authorization/policyDefinitions/${local.builtin.ai_approved_models}"
    parameter_values = jsonencode({
      effect            = { value = "Deny" }
      allowedAssetIds   = { value = "[parameters('approvedModelAssetIds')]" }
      allowedPublishers = { value = [] }
    })
  }

  policy_definition_reference {
    reference_id         = "modelEligibility"
    policy_definition_id = "/providers/Microsoft.Authorization/policyDefinitions/${local.builtin.ai_model_eligibility}"
    parameter_values = jsonencode({
      effect                   = { value = "Deny" }
      denyPreviewModels        = { value = true }
      onlyAllowDirectFromAzure = { value = true }
    })
  }

  policy_definition_reference {
    reference_id         = "diagnosticLogs"
    policy_definition_id = "/providers/Microsoft.Authorization/policyDefinitions/${local.builtin.ai_diagnostic_logs}"
    parameter_values     = jsonencode({ effect = { value = "AuditIfNotExists" } })
  }

  policy_definition_reference {
    reference_id         = "privateLink"
    policy_definition_id = "/providers/Microsoft.Authorization/policyDefinitions/${local.builtin.ai_private_link}"
    parameter_values     = jsonencode({ effect = { value = "Audit" } })
  }

  dynamic "policy_definition_reference" {
    for_each = toset(local.prompt_filters)
    content {
      reference_id         = "promptFilter${replace(policy_definition_reference.value, " ", "")}"
      policy_definition_id = "/providers/Microsoft.Authorization/policyDefinitions/${local.builtin.ai_prompt_filtering}"
      parameter_values = jsonencode({
        effect                   = { value = "Audit" }
        filterName               = { value = policy_definition_reference.value }
        allowedEnabledForPrompt  = { value = ["true"] }
        allowedBlockingForPrompt = { value = ["true"] }
      })
    }
  }

  dynamic "policy_definition_reference" {
    for_each = toset(local.completion_filters)
    content {
      reference_id         = "completionFilter${replace(policy_definition_reference.value, " ", "")}"
      policy_definition_id = "/providers/Microsoft.Authorization/policyDefinitions/${local.builtin.ai_completion_filtering}"
      parameter_values = jsonencode({
        effect                       = { value = "Audit" }
        filterName                   = { value = policy_definition_reference.value }
        allowedEnabledForCompletion  = { value = ["true"] }
        allowedBlockingForCompletion = { value = ["true"] }
      })
    }
  }
}

resource "azurerm_management_group_policy_set_definition" "baseline" {
  name                = "${var.prefix}-ini-baseline-v1"
  display_name        = "Lab platform baseline v1"
  description         = "Region and tagging guardrails for everything under the lab root."
  policy_type         = "Custom"
  management_group_id = local.mg.root

  parameters = jsonencode({
    allowedLocations = { type = "Array", metadata = { displayName = "Allowed locations", strongType = "location" } }
  })

  policy_definition_reference {
    reference_id         = "allowedLocations"
    policy_definition_id = "/providers/Microsoft.Authorization/policyDefinitions/${local.builtin.allowed_locations}"
    parameter_values = jsonencode({
      effect                 = { value = "Deny" }
      listOfAllowedLocations = { value = "[parameters('allowedLocations')]" }
    })
  }

  policy_definition_reference {
    reference_id         = "allowedResourceGroupLocations"
    policy_definition_id = "/providers/Microsoft.Authorization/policyDefinitions/${local.builtin.allowed_rg_locations}"
    parameter_values = jsonencode({
      effect                 = { value = "Deny" }
      listOfAllowedLocations = { value = "[parameters('allowedLocations')]" }
    })
  }

  policy_definition_reference {
    reference_id         = "resourceGroupManagedByTag"
    policy_definition_id = azurerm_policy_definition.rg_tag_audit.id
    parameter_values     = jsonencode({ tagName = { value = "managed-by" } })
  }
}
