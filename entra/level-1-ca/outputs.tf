output "policy_states" {
  description = "State of each Conditional Access policy, keyed by display name. enabledForReportingButNotEnforced is report-only."
  value       = { for p in azuread_conditional_access_policy.baseline : p.display_name => p.state }
}

output "trusted_countries_location_id" {
  description = "Object ID of lab-nl-trusted-countries."
  value       = azuread_named_location.trusted_countries.object_id
}
