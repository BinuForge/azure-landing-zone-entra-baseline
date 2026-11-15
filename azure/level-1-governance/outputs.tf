output "assignment_ids" {
  description = "Policy assignment IDs, keyed by purpose. Level 3 adds scoped exemptions against these, for example for APIM's management IP."
  value = {
    baseline          = azurerm_management_group_policy_assignment.baseline.id
    ai_account        = azurerm_management_group_policy_assignment.ai_account.id
    ai_deployments    = azurerm_management_group_policy_assignment.ai_deployments.id
    ai_kinds          = azurerm_management_group_policy_assignment.ai_kinds.id
    corp_no_public_ip = azurerm_management_group_policy_assignment.corp_no_public_ip.id
    mcsb              = azurerm_management_group_policy_assignment.mcsb.id
  }
}
