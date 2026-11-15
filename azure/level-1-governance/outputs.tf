output "assignment_ids" {
  description = "Policy assignment IDs, keyed by purpose. Level 3 adds scoped exemptions against these, for example for APIM's management IP."
  value = {
    baseline          = azurerm_management_group_policy_assignment.baseline.id
    ai                = azurerm_management_group_policy_assignment.ai.id
    corp_no_public_ip = azurerm_management_group_policy_assignment.corp_no_public_ip.id
    mcsb              = azurerm_management_group_policy_assignment.mcsb.id
  }
}
