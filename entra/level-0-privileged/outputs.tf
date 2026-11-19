output "breakglass_exclusion_group_id" {
  description = "Object ID of the group every Conditional Access policy excludes. Level 1 ca reads it (ADR-0013)."
  value       = azuread_group.breakglass_exclusion.object_id
}

output "emergency_au_id" {
  description = "Object ID of the restricted management administrative unit that holds Tier 0 objects."
  value       = msgraph_resource.emergency_au.id
}
