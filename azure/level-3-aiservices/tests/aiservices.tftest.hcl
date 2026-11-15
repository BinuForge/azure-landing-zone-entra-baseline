# Runs with mock providers: no sign-in, no network calls, nothing created.
mock_provider "azurerm" {
  override_during = plan

  mock_data "azurerm_resource_group" {
    defaults = {
      name     = "lab-rg-aiservices-prd-ae"
      location = "australiaeast"
    }
  }
}

mock_provider "tfe" {}

override_data {
  target = data.azurerm_client_config.current
  values = { tenant_id = "00000000-0000-0000-0000-000000000002" }
}

override_data {
  target          = data.tfe_outputs.management
  override_during = plan
  values = {
    nonsensitive_values = {
      log_analytics_workspace_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/lab-rg-management-prd-ae/providers/Microsoft.OperationalInsights/workspaces/lab-log-management-prd-ae"
    }
  }
}

override_data {
  target          = data.tfe_outputs.connectivity
  override_during = plan
  values = {
    nonsensitive_values = {
      hub_vnet_id         = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/lab-rg-connectivity-prd-ae/providers/Microsoft.Network/virtualNetworks/lab-vnet-hub-prd-ae"
      hub_vnet_name       = "lab-vnet-hub-prd-ae"
      resource_group_name = "lab-rg-connectivity-prd-ae"
      hub_address_space   = "10.10.0.0/22"
    }
  }
}

override_data {
  target          = data.tfe_outputs.dns
  override_during = plan
  values = {
    nonsensitive_values = {
      resource_group_name = "lab-rg-dns-prd-ae"
      private_dns_zone_ids = {
        cognitiveservices = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/lab-rg-dns-prd-ae/providers/Microsoft.Network/privateDnsZones/privatelink.cognitiveservices.azure.com"
        openai            = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/lab-rg-dns-prd-ae/providers/Microsoft.Network/privateDnsZones/privatelink.openai.azure.com"
        aiservices        = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/lab-rg-dns-prd-ae/providers/Microsoft.Network/privateDnsZones/privatelink.services.ai.azure.com"
      }
    }
  }
}

run "account_has_no_public_path_and_no_keys" {
  command = plan

  assert {
    condition     = azurerm_cognitive_account.this.public_network_access_enabled == false
    error_message = "Public network access must be off (threat model C-08)."
  }

  assert {
    condition     = azurerm_cognitive_account.this.local_auth_enabled == false
    error_message = "Key authentication must be off (threat model C-07)."
  }

  assert {
    condition     = one(azurerm_cognitive_account.this.network_acls).default_action == "Deny" && one(azurerm_cognitive_account.this.network_acls).bypass == "None"
    error_message = "Network rules must deny by default with no trusted-service bypass."
  }

  assert {
    condition     = azurerm_cognitive_account.this.kind == "AIServices"
    error_message = "Only the AIServices kind is allowed (level 1 policy)."
  }
}

run "private_endpoint_registers_in_all_central_zones" {
  command = plan

  assert {
    condition     = length(one(azurerm_private_endpoint.foundry.private_dns_zone_group).private_dns_zone_ids) == 3
    error_message = "The private endpoint must register in all three central zones."
  }

  assert {
    condition     = length(azurerm_private_dns_zone_virtual_network_link.spoke) == 3 && alltrue([for l in azurerm_private_dns_zone_virtual_network_link.spoke : l.resource_group_name == "lab-rg-dns-prd-ae"])
    error_message = "The spoke must link to the central zones in the DNS group, not zones of its own."
  }
}

run "both_peering_sides_exist_without_transit" {
  command = plan

  assert {
    condition     = azurerm_virtual_network_peering.hub_to_spoke.resource_group_name == "lab-rg-connectivity-prd-ae"
    error_message = "The hub side of the peering must sit in the connectivity group."
  }

  assert {
    condition = alltrue([for p in [azurerm_virtual_network_peering.spoke_to_hub, azurerm_virtual_network_peering.hub_to_spoke] :
    !p.allow_forwarded_traffic && !p.allow_gateway_transit && !p.use_remote_gateways])
    error_message = "Peering must not forward traffic or use gateways."
  }
}

run "overlapping_spoke_is_rejected" {
  command = plan

  variables {
    spoke_address_space = "10.10.1.0/24"
  }

  expect_failures = [azurerm_virtual_network.spoke]
}

run "deployments_are_pinned_global_standard_with_the_strict_guardrail" {
  command = plan

  assert {
    condition     = alltrue([for d in azurerm_cognitive_deployment.this : one(d.sku).name == "GlobalStandard" && d.version_upgrade_option == "NoAutoUpgrade"])
    error_message = "Deployments must be Global Standard (ADR-0009) with the model version pinned."
  }

  assert {
    condition     = alltrue([for d in azurerm_cognitive_deployment.this : d.rai_policy_name == "lab-rai-strict-v1"])
    error_message = "Every deployment must use the strict guardrail."
  }

  assert {
    condition     = keys(azurerm_cognitive_deployment.this) == ["gpt-5-mini"]
    error_message = "Only gpt-5-mini is deployed; gpt-4.1-mini is legacy."
  }
}

run "guardrail_blocks_prompt_shields_and_protected_material" {
  command = plan

  assert {
    condition = alltrue([for name in ["Jailbreak", "Indirect Attack", "Protected Material Text", "Protected Material Code"] :
      anytrue([for f in azurerm_cognitive_account_rai_policy.strict.content_filter : f.name == name && f.block_enabled && f.filter_enabled])
    ])
    error_message = "Prompt Shields and protected material filters must block (threat model C-02)."
  }
}

run "prompt_content_is_off_by_default_and_separate" {
  command = plan

  assert {
    condition     = length(azurerm_monitor_diagnostic_setting.foundry_prompts) == 0
    error_message = "Request and response content logging must be off by default (ADR-0010)."
  }

  assert {
    condition     = !anytrue([for l in azurerm_monitor_diagnostic_setting.foundry_ops.enabled_log : l.category == "RequestResponse"])
    error_message = "Prompt content must never go to the ops workspace."
  }

  assert {
    condition     = azurerm_log_analytics_workspace.prompts.local_authentication_enabled == false
    error_message = "The prompt workspace must be keyless."
  }
}

run "prompt_logging_flag_sends_content_to_the_prompt_workspace_only" {
  command = plan

  variables {
    enable_prompt_logging = true
  }

  assert {
    condition     = length(azurerm_monitor_diagnostic_setting.foundry_prompts) == 1
    error_message = "With the flag on, request and response content must be logged."
  }
}

run "gateway_is_off_by_default_and_costs_nothing" {
  command = plan

  assert {
    condition     = length(azurerm_api_management.this) == 0 && length(azurerm_public_ip.apim) == 0
    error_message = "APIM and its public IP must not exist unless enable_apim is true."
  }
}

run "gateway_when_on_is_external_with_identity_and_one_role" {
  command = plan

  variables {
    enable_apim = true
  }

  assert {
    condition     = azurerm_api_management.this[0].sku_name == "Developer_1" && azurerm_api_management.this[0].virtual_network_type == "External"
    error_message = "The gateway is APIM Developer in external VNet mode (ADR-0008)."
  }

  assert {
    condition     = azurerm_role_assignment.apim_openai_user[0].role_definition_name == "Cognitive Services OpenAI User"
    error_message = "APIM's identity must hold OpenAI User, the inference-only role without listkeys."
  }

  assert {
    condition     = azurerm_api_management_api.openai[0].subscription_required == false
    error_message = "Callers authenticate with Entra tokens, never subscription keys."
  }

  assert {
    condition     = length(azurerm_api_management_api_operation.chat) == 1 && azurerm_api_management_api_operation.chat[0].url_template == "/deployments/{deployment-id}/chat/completions"
    error_message = "Only chat completions may be exposed through the gateway."
  }
}

run "gateway_policy_enforces_identity_limit_kill_switch_and_identity_swap" {
  command = plan

  variables {
    enable_apim = true
  }

  assert {
    condition = alltrue([for fragment in [
      "<validate-jwt",
      "<audience>api://00000000-0000-0000-0000-000000000002/lab-aigateway</audience>",
      "<value>AI.Invoke</value>",
      "{{ai-kill-switch}}",
      "<llm-token-limit",
      "tokens-per-minute=\"2000\"",
      "<set-header name=\"Authorization\" exists-action=\"delete\" />",
      "<authentication-managed-identity resource=\"https://cognitiveservices.azure.com\" />",
    ] : strcontains(azurerm_api_management_api_policy.openai[0].xml_content, fragment)])
    error_message = "The gateway policy must check the Entra role, limit tokens, honour the kill switch and swap to APIM's identity."
  }
}

run "apim_subnet_denies_other_internet_egress" {
  command = plan

  assert {
    condition     = azurerm_network_security_rule.apim["deny-internet-outbound"].access == "Deny" && azurerm_network_security_rule.apim["deny-internet-outbound"].destination_address_prefix == "Internet"
    error_message = "The APIM subnet must deny outbound internet traffic apart from the listed dependencies."
  }

  assert {
    condition     = alltrue([for r in azurerm_network_security_rule.apim : r.destination_port_ranges == null || !contains(r.destination_port_ranges, "*")])
    error_message = "Azure rejects '*' inside a list of port ranges; any-port rules must use destination_port_range."
  }
}
