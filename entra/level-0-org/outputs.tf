output "persona_group_ids" {
  description = "Object ID of each persona group, keyed by persona. Conditional Access reads these (ADR-0013)."
  value       = { for k, g in azuread_group.persona : k => g.object_id }
}
