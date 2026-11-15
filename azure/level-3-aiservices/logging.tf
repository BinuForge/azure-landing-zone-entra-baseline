# Prompt content is the most sensitive data in the platform (ADR-0010): its own workspace, its own
# access, a small cap, and content only when the flag is on.
resource "azurerm_log_analytics_workspace" "prompts" {
  name                            = "${var.prefix}-log-prompts-prd-ae"
  resource_group_name             = local.rg
  location                        = local.location
  sku                             = "PerGB2018"
  retention_in_days               = 30
  daily_quota_gb                  = var.prompt_workspace_daily_quota_gb
  local_authentication_enabled    = false
  allow_resource_only_permissions = true
  tags                            = local.tags
}

# Who called, when, how many tokens: always on, into the ops workspace. No prompt content here.
resource "azurerm_monitor_diagnostic_setting" "foundry_ops" {
  name                       = "${var.prefix}-diag-foundry-ops"
  target_resource_id         = azurerm_cognitive_account.this.id
  log_analytics_workspace_id = local.management.log_analytics_workspace_id

  enabled_log {
    category = "Audit"
  }

  enabled_log {
    category = "AzureOpenAIRequestUsage"
  }

  enabled_metric {
    category = "AllMetrics"
  }
}

# Full request and response content, only while the flag is on.
resource "azurerm_monitor_diagnostic_setting" "foundry_prompts" {
  count = var.enable_prompt_logging ? 1 : 0

  name                       = "${var.prefix}-diag-foundry-prompts"
  target_resource_id         = azurerm_cognitive_account.this.id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.prompts.id

  enabled_log {
    category = "RequestResponse"
  }
}

# Every query against the prompt workspace is logged in the ops workspace, so reading prompt content is
# never silent (ADR-0010). The alert on these records comes with the ops agent.
resource "azurerm_monitor_diagnostic_setting" "prompts_query_audit" {
  name                       = "${var.prefix}-diag-prompts-query-audit"
  target_resource_id         = azurerm_log_analytics_workspace.prompts.id
  log_analytics_workspace_id = local.management.log_analytics_workspace_id

  enabled_log {
    category = "Audit"
  }
}
