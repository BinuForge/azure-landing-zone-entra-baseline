# Authentication methods (ADR-0018): passkeys and Microsoft Authenticator on, Temporary Access Pass for
# onboarding a passkey, SMS and voice off because they can be phished and SIM-swapped. Every method is
# for all users; Conditional Access decides which strength each persona needs.
locals {
  methods_url             = "policies/authenticationMethodsPolicy/authenticationMethodConfigurations"
  passkey_profile_default = "00000000-0000-0000-0000-000000000001"

  # Passkey profiles replace isAttestationEnforced and keyRestrictions (deprecated, removed October 2027).
  # A tenant without profiles still takes the old properties, so the body follows what the tenant returns.
  has_passkey_profiles = length(try(data.msgraph_resource.fido2.output.profiles, [])) > 0

  fido2_common = {
    "@odata.type"                    = "#microsoft.graph.fido2AuthenticationMethodConfiguration"
    state                            = "enabled"
    isSelfServiceRegistrationAllowed = true
  }

  # Device-bound passkeys only (security keys, Microsoft Authenticator), with attestation checked when a
  # key is registered. Synced passkeys can be copied to devices the tenant never sees.
  fido2_profiles = {
    includeTargets = [{
      targetType             = "group"
      id                     = "all_users"
      isRegistrationRequired = false
      allowedPasskeyProfiles = [local.passkey_profile_default]
    }]
    passkeyProfiles = [{
      id                     = local.passkey_profile_default
      name                   = "Default passkey profile"
      passkeyTypes           = "deviceBound"
      attestationEnforcement = "registrationOnly"
      keyRestrictions        = { isEnforced = false, enforcementType = "allow", aaGuids = [] }
    }]
  }

  fido2_legacy = {
    includeTargets        = [{ targetType = "group", id = "all_users", isRegistrationRequired = false }]
    isAttestationEnforced = true
  }

  other_methods = {
    microsoftAuthenticator = {
      "@odata.type"         = "#microsoft.graph.microsoftAuthenticatorAuthenticationMethodConfiguration"
      state                 = "enabled"
      isSoftwareOathEnabled = false # No one-time codes from the app: a typed code is the easiest to phish
    }
    temporaryAccessPass = {
      "@odata.type"            = "#microsoft.graph.temporaryAccessPassAuthenticationMethodConfiguration"
      state                    = "enabled"
      isUsableOnce             = true
      defaultLength            = 8
      defaultLifetimeInMinutes = 60
      minimumLifetimeInMinutes = 60
      maximumLifetimeInMinutes = 480
      includeTargets           = [{ targetType = "group", id = "all_users", isRegistrationRequired = false }]
    }
    sms = {
      "@odata.type" = "#microsoft.graph.smsAuthenticationMethodConfiguration"
      state         = "disabled"
    }
    voice = {
      "@odata.type" = "#microsoft.graph.voiceAuthenticationMethodConfiguration"
      state         = "disabled"
    }
  }
}

# Read by the plan identity with Policy.Read.All, before anything is sent.
data "msgraph_resource" "fido2" {
  url                    = "${local.methods_url}/fido2"
  response_export_values = { profiles = "passkeyProfiles" }
}

resource "msgraph_update_resource" "fido2" {
  url = "${local.methods_url}/fido2"

  # merge skips null, so only one of the two shapes is sent.
  body = merge(
    local.fido2_common,
    local.has_passkey_profiles ? local.fido2_profiles : null,
    local.has_passkey_profiles ? null : local.fido2_legacy,
  )
}

resource "msgraph_update_resource" "method" {
  for_each = local.other_methods

  url  = "${local.methods_url}/${each.key}"
  body = each.value
}
