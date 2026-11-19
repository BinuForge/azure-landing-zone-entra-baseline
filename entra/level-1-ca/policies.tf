# The Conditional Access baseline (ADR-0017). Each policy is one entry of data, so every policy gets the
# same break-glass exclusion and the same checks. Names follow docs/naming.md.
locals {
  # A policy moves here only when its report-only results meet ADR-0017's bar. Everything else stays
  # report-only: evaluated and logged on every sign-in, never enforced.
  enforced = []

  defaults = {
    users_all        = false
    groups           = []
    roles            = []
    guests           = false
    client_app_types = ["all"]
    transfer_methods = []
    sign_in_risk     = []
    user_risk        = []
    outside_trusted  = false
    controls         = []
    strength         = null
    operator         = "OR"
    every_time       = false
  }

  policy_specs = {
    CA001 = {
      name             = "CA001-Global-BlockLegacyAuth"
      users_all        = true
      client_app_types = ["exchangeActiveSync", "other"]
      controls         = ["block"]
    }
    CA002 = {
      name             = "CA002-Global-BlockDeviceCodeFlow"
      users_all        = true
      transfer_methods = ["deviceCodeFlow", "authenticationTransfer"]
      controls         = ["block"]
    }
    CA003 = {
      name            = "CA003-Global-BlockUntrustedCountries"
      users_all       = true
      outside_trusted = true
      controls        = ["block"]
    }
    CA004 = {
      name     = "CA004-Admins-RequirePhishingResistantMfa"
      roles    = values(local.admin_roles)
      strength = local.phishing_resistant_mfa
    }
    CA005 = {
      name     = "CA005-Internals-RequireMfa"
      groups   = [local.personas.internals]
      controls = ["mfa"]
    }
    # The guest condition, not the guests group: it also covers external users whose type is Member.
    CA006 = {
      name     = "CA006-Guests-RequireMfa"
      guests   = true
      controls = ["mfa"]
    }
    # Identity Protection needs Entra ID P2. Risk is re-checked at every sign-in.
    CA007 = {
      name         = "CA007-Global-RiskySignInRequireMfa"
      users_all    = true
      sign_in_risk = ["medium", "high"]
      controls     = ["mfa"]
      every_time   = true
    }
    CA008 = {
      name       = "CA008-Global-HighUserRiskRequirePasswordChange"
      users_all  = true
      user_risk  = ["high"]
      controls   = ["mfa", "passwordChange"]
      operator   = "AND"
      every_time = true
    }
  }

  policies = { for k, p in local.policy_specs : k => merge(local.defaults, p) }
}

resource "azuread_conditional_access_policy" "baseline" {
  for_each = local.policies

  display_name = each.value.name
  state        = contains(local.enforced, each.key) ? "enabled" : "enabledForReportingButNotEnforced"

  conditions {
    client_app_types                     = each.value.client_app_types
    authentication_flow_transfer_methods = length(each.value.transfer_methods) > 0 ? each.value.transfer_methods : null
    sign_in_risk_levels                  = length(each.value.sign_in_risk) > 0 ? each.value.sign_in_risk : null
    user_risk_levels                     = length(each.value.user_risk) > 0 ? each.value.user_risk : null

    applications {
      included_applications = ["All"]
    }

    users {
      included_users  = each.value.users_all ? ["All"] : null
      included_groups = length(each.value.groups) > 0 ? each.value.groups : null
      included_roles  = length(each.value.roles) > 0 ? each.value.roles : null

      dynamic "included_guests_or_external_users" {
        for_each = each.value.guests ? [1] : []
        content {
          guest_or_external_user_types = local.external_user_types
          external_tenants {
            membership_kind = "all"
          }
        }
      }

      excluded_groups = [local.breakglass_group_id]
    }

    dynamic "locations" {
      for_each = each.value.outside_trusted ? [1] : []
      content {
        included_locations = ["All"]
        excluded_locations = [azuread_named_location.trusted_countries.object_id]
      }
    }
  }

  grant_controls {
    operator                          = each.value.operator
    built_in_controls                 = length(each.value.controls) > 0 ? each.value.controls : null
    authentication_strength_policy_id = each.value.strength
  }

  dynamic "session_controls" {
    for_each = each.value.every_time ? [1] : []
    content {
      sign_in_frequency_interval            = "everyTime"
      sign_in_frequency_authentication_type = "primaryAndSecondaryAuthentication"
    }
  }

  lifecycle {
    precondition {
      condition     = can(regex(local.guid, local.breakglass_group_id))
      error_message = "No break-glass exclusion group from lab-entra-l0-privileged-prd. Apply level 0 privileged first; a policy without the exclusion could lock every administrator out."
    }
  }
}
