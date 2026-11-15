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
# never silent (ADR-0010). The alert below fires on these records.
resource "azurerm_monitor_diagnostic_setting" "prompts_query_audit" {
  name                       = "${var.prefix}-diag-prompts-query-audit"
  target_resource_id         = azurerm_log_analytics_workspace.prompts.id
  log_analytics_workspace_id = local.management.log_analytics_workspace_id

  enabled_log {
    category = "Audit"
  }
}

# Any query against the prompt workspace raises a severity 1 alert (threat model C-16). The rule reads the
# ops workspace, where the query audit lands, with its own identity, which holds Log Analytics Reader
# there and nothing else.
resource "azurerm_monitor_scheduled_query_rules_alert_v2" "prompts_queried" {
  name                 = "${var.prefix}-alert-prompts-queried-prd-ae"
  resource_group_name  = local.rg
  location             = local.location
  description          = "Someone queried the prompt workspace (ADR-0010, threat model C-16)."
  severity             = 1
  scopes               = [local.management.log_analytics_workspace_id]
  evaluation_frequency = "PT5M"
  # Audit records can arrive minutes late, so each falls inside three evaluations.
  window_duration         = "PT15M"
  auto_mitigation_enabled = false
  # The identity's role is created after the rule, so Azure cannot test the query at creation.
  skip_query_validation = true
  tags                  = local.tags

  criteria {
    query                   = "LAQueryLogs | where _ResourceId =~ '${azurerm_log_analytics_workspace.prompts.id}'"
    time_aggregation_method = "Count"
    operator                = "GreaterThan"
    threshold               = 0
  }

  identity {
    type = "SystemAssigned"
  }
}

# Allowed by level 3's management delegation, which grants this role only (ADR-0012).
resource "azurerm_role_assignment" "prompts_queried_reads_ops" {
  scope                = local.management.log_analytics_workspace_id
  role_definition_name = "Log Analytics Reader"
  principal_id         = one(azurerm_monitor_scheduled_query_rules_alert_v2.prompts_queried.identity).principal_id
  principal_type       = "ServicePrincipal"
  description          = "Prompt query alert reads the query audit, threat model C-16."
}
