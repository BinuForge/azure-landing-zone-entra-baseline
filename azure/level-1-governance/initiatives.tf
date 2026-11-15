# Deny where Microsoft's policy is generally available; Audit where it is preview, because a preview policy
# that denies can break deployments when Microsoft changes it.
# The account plane: how the Foundry account itself is exposed and authenticated.
resource "azurerm_management_group_policy_set_definition" "ai_account" {
  name                = "${var.prefix}-ini-ai-account-v1"
  display_name        = "Lab AI services account baseline v1"
  description         = "Private, keyless, logged Foundry accounts (threat-model-ai.md C-07, C-08, C-15)."
  policy_type         = "Custom"
  management_group_id = local.mg.root

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
    reference_id         = "diagnosticLogs"
    policy_definition_id = "/providers/Microsoft.Authorization/policyDefinitions/${local.builtin.ai_diagnostic_logs}"
    parameter_values     = jsonencode({ effect = { value = "AuditIfNotExists" } })
  }

  policy_definition_reference {
    reference_id         = "privateLink"
    policy_definition_id = "/providers/Microsoft.Authorization/policyDefinitions/${local.builtin.ai_private_link}"
    parameter_values     = jsonencode({ effect = { value = "Audit" } })
  }
}

# The data plane: what may run on an account. These policies use the Microsoft.CognitiveServices.Data
# mode, so they are kept apart from the account-plane initiative.
resource "azurerm_management_group_policy_set_definition" "ai_deployments" {
  name                = "${var.prefix}-ini-ai-deployments-v1"
  display_name        = "Lab AI model deployment baseline v1"
  description         = "Approved, generally available models with Prompt Shields and protected-material filters (C-02, C-24)."
  policy_type         = "Custom"
  management_group_id = local.mg.root

  parameters = jsonencode({
    approvedModelAssetIds = { type = "Array", metadata = { displayName = "Approved model asset IDs" } }
  })

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
