output "breakglass_exclusion_group_id" {
  description = "Object ID of the group every Conditional Access policy excludes. Level 1 ca reads it (ADR-0013)."
  value       = azuread_group.breakglass_exclusion.object_id
}

output "emergency_au_id" {
  description = "Object ID of the restricted management administrative unit that holds Tier 0 objects."
  value       = msgraph_resource.emergency_au.id
}

output "cloudapp_admin_group_id" {
  description = "Object ID of lab-grp-role-cloudappadmin, whose members review admin consent requests. Null until pim/Set-Pim.ps1 creates it. Level 1 governance reads it (ADR-0019)."
  value       = try(one([for g in data.msgraph_resource.cloudapp_admin_group.output.groups : g.id if g.isAssignableToRole]), null)
}
