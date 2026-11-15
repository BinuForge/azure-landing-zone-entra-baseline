# Runs with a mock provider: no sign-in, no network calls, nothing created.
mock_provider "azurerm" {
  override_during = plan

  mock_resource "azurerm_policy_definition" {
    defaults = {
      id = "/providers/Microsoft.Management/managementGroups/lab-mg-root/providers/Microsoft.Authorization/policyDefinitions/lab-pol-rg-tag-audit-v1"
    }
  }
  mock_resource "azurerm_management_group_policy_set_definition" {
    defaults = {
      id = "/providers/Microsoft.Management/managementGroups/lab-mg-root/providers/Microsoft.Authorization/policySetDefinitions/mock"
    }
  }
  mock_resource "azurerm_management_group_policy_assignment" {
    defaults = {
      id = "/providers/Microsoft.Management/managementGroups/mock/providers/Microsoft.Authorization/policyAssignments/mock"
    }
  }
  mock_data "azurerm_resource_group" {
    defaults = {
      id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/lab-rg-study-np-ae"
    }
  }
}

override_data {
  target = data.azurerm_management_group.this["landingzones"]
  values = { id = "/providers/Microsoft.Management/managementGroups/lab-mg-landingzones" }
}

override_data {
  target = data.azurerm_management_group.this["corp"]
  values = { id = "/providers/Microsoft.Management/managementGroups/lab-mg-corp" }
}

override_data {
  target = data.azurerm_management_group.this["root"]
  values = { id = "/providers/Microsoft.Management/managementGroups/lab-mg-root" }
}

run "ai_baseline_covers_landing_zones" {
  command = plan

  assert {
    condition     = azurerm_management_group_policy_assignment.ai.management_group_id == "/providers/Microsoft.Management/managementGroups/lab-mg-landingzones"
    error_message = "The AI baseline must apply to every landing zone, including corp."
  }

  assert {
    condition     = jsondecode(azurerm_management_group_policy_assignment.ai.parameters).approvedModelAssetIds.value == ["azureml://registries/azure-openai/models/gpt-4.1-mini/", "azureml://registries/azure-openai/models/gpt-5-mini/"]
    error_message = "Only gpt-4.1-mini and gpt-5-mini are approved."
  }
}

run "generally_available_ai_controls_deny" {
  command = plan

  assert {
    condition = alltrue([
      for ref in azurerm_management_group_policy_set_definition.ai.policy_definition_reference :
      jsondecode(ref.parameter_values).effect.value == "Deny"
      if contains(["restrictNetworkAccess", "disableLocalAuth", "approvedModels", "modelEligibility"], ref.reference_id)
    ])
    error_message = "Network, keyless, approved-model and eligibility controls must deny."
  }

  assert {
    condition = alltrue([
      for ref in azurerm_management_group_policy_set_definition.ai.policy_definition_reference :
      jsondecode(ref.parameter_values).effect.value == "Audit"
      if startswith(ref.reference_id, "promptFilter") || startswith(ref.reference_id, "completionFilter")
    ])
    error_message = "Preview guardrail policies must audit, never deny."
  }

  assert {
    condition     = length([for ref in azurerm_management_group_policy_set_definition.ai.policy_definition_reference : ref if startswith(ref.reference_id, "promptFilter")]) == 2
    error_message = "Prompt Shields jailbreak and indirect attack filters must both be audited."
  }
}

run "regions_are_limited_to_australia" {
  command = plan

  assert {
    condition     = jsondecode(azurerm_management_group_policy_assignment.baseline.parameters).allowedLocations.value == ["australiaeast", "australiasoutheast"]
    error_message = "Only Australia East and Australia Southeast are allowed."
  }
}

run "corp_denies_public_ips" {
  command = plan

  assert {
    condition     = jsondecode(azurerm_management_group_policy_assignment.corp_no_public_ip.parameters).effect.value == "Deny"
    error_message = "Corp must deny public IP addresses."
  }
}

run "benchmark_audits_only" {
  command = plan

  assert {
    condition     = azurerm_management_group_policy_assignment.mcsb.enforce == false
    error_message = "The Microsoft cloud security benchmark is assigned for visibility, not enforcement."
  }
}

run "study_waiver_is_scoped_and_expires" {
  command = plan

  assert {
    condition     = alltrue([for e in azurerm_resource_group_policy_exemption.study : e.exemption_category == "Waiver" && e.expires_on != null])
    error_message = "Study exemptions must be waivers with an expiry."
  }

  assert {
    condition     = alltrue([for e in azurerm_resource_group_policy_exemption.study : endswith(e.resource_group_id, "/lab-rg-study-np-ae")])
    error_message = "Study exemptions may only cover the study group."
  }
}

run "study_waiver_longer_than_30_days_is_rejected" {
  command = plan

  variables {
    study_exemption_expires_on = "2030-01-01T00:00:00Z"
  }

  expect_failures = [azurerm_resource_group_policy_exemption.study]
}

run "assignment_names_fit_the_management_group_limit" {
  command = plan

  assert {
    condition = alltrue([for n in [
      azurerm_management_group_policy_assignment.baseline.name,
      azurerm_management_group_policy_assignment.ai.name,
      azurerm_management_group_policy_assignment.corp_no_public_ip.name,
      azurerm_management_group_policy_assignment.mcsb.name,
    ] : length(n) <= 24])
    error_message = "Assignment names at management group scope must be 24 characters or fewer."
  }
}
