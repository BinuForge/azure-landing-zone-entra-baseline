output "passkey_profiles_in_use" {
  description = "True if the tenant takes passkey profiles, so FIDO2 is device-bound only with attestation at registration."
  value       = local.has_passkey_profiles
}

output "methods_disabled" {
  description = "Authentication methods this level turns off."
  value       = sort([for k, m in local.other_methods : k if m.state == "disabled"])
}
