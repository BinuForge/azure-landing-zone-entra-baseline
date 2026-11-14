output "management_group_ids" {
  description = "Management group resource ID, keyed by short name (root, platform, corp, ...). Read by level 1 for policy assignments."
  value = merge(
    { root = azurerm_management_group.root.id },
    { for k, mg in azurerm_management_group.tier_2 : k => mg.id },
    { for k, mg in azurerm_management_group.tier_3 : k => mg.id },
  )
}
