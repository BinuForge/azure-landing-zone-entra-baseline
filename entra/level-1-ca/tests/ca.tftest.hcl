# Runs with mock providers: no sign-in, no network calls, nothing created.
mock_provider "azuread" {}

mock_provider "tfe" {}

override_data {
  target          = data.tfe_outputs.org
  override_during = plan
  values = {
    nonsensitive_values = {
      persona_group_ids = {
        internals = "00000000-0000-0000-0000-0000000000b1"
        guests    = "00000000-0000-0000-0000-0000000000b2"
      }
    }
  }
}

override_data {
  target          = data.tfe_outputs.privileged
  override_during = plan
  values = {
    nonsensitive_values = {
      breakglass_exclusion_group_id = "00000000-0000-0000-0000-0000000000e1"
    }
  }
}

run "eight_policies_named_by_the_convention" {
  command = plan

  assert {
    condition     = length(azuread_conditional_access_policy.baseline) == 8
    error_message = "The baseline is CA001 to CA008 (ADR-0017)."
  }

  assert {
    condition = alltrue([for k, p in azuread_conditional_access_policy.baseline :
    can(regex("^${k}-(Global|Admins|Internals|Guests|WorkloadIdentities)-[A-Za-z]+$", p.display_name))])
    error_message = "Policy names are CA<nnn>-<Persona>-<Purpose> (docs/naming.md)."
  }
}

run "every_policy_excludes_break_glass_and_only_break_glass" {
  command = plan

  assert {
    condition = alltrue([for p in azuread_conditional_access_policy.baseline :
    one(one(p.conditions).users).excluded_groups == tolist(["00000000-0000-0000-0000-0000000000e1"])])
    error_message = "Every policy excludes lab-grp-excl-breakglass, and no other group, so nobody else can opt out."
  }

  assert {
    condition = alltrue([for p in azuread_conditional_access_policy.baseline :
      one(one(p.conditions).users).excluded_users == null &&
    one(one(p.conditions).users).excluded_roles == null])
    error_message = "Exclusions are by group only, so they all sit in the restricted unit."
  }
}

run "nothing_is_enforced_until_its_report_is_read" {
  command = plan

  assert {
    condition     = alltrue([for p in azuread_conditional_access_policy.baseline : p.state == "enabledForReportingButNotEnforced"])
    error_message = "Every policy starts report-only. Enforcing one is a reviewed change to local.enforced, and this test (ADR-0017)."
  }
}

run "admins_are_targeted_by_role_with_phishing_resistant_mfa" {
  command = plan

  assert {
    condition     = length(one(one(azuread_conditional_access_policy.baseline["CA004"].conditions).users).included_roles) == 14
    error_message = "CA004 covers Microsoft's 14 privileged roles."
  }

  assert {
    condition     = contains(one(one(azuread_conditional_access_policy.baseline["CA004"].conditions).users).included_roles, "62e90394-69f5-4237-9190-012177145e10")
    error_message = "CA004 covers Global Administrator."
  }

  assert {
    condition     = one(azuread_conditional_access_policy.baseline["CA004"].grant_controls).authentication_strength_policy_id == "/policies/authenticationStrengthPolicies/00000000-0000-0000-0000-000000000004"
    error_message = "Administrators need the built-in phishing-resistant MFA strength."
  }
}

run "personas_and_blocks_target_the_right_users" {
  command = plan

  assert {
    condition     = one(one(azuread_conditional_access_policy.baseline["CA005"].conditions).users).included_groups == tolist(["00000000-0000-0000-0000-0000000000b1"])
    error_message = "CA005 targets the internals persona group from level 0."
  }

  assert {
    condition     = length(one(one(azuread_conditional_access_policy.baseline["CA006"].conditions).users).included_guests_or_external_users) == 1
    error_message = "CA006 targets every external user type, not only the guests group."
  }

  assert {
    condition = alltrue([for k in ["CA001", "CA002", "CA003"] :
      one(azuread_conditional_access_policy.baseline[k].grant_controls).built_in_controls == tolist(["block"]) &&
    one(one(azuread_conditional_access_policy.baseline[k].conditions).users).included_users == tolist(["All"])])
    error_message = "CA001 to CA003 block, for all users."
  }

  assert {
    condition     = toset(one(azuread_conditional_access_policy.baseline["CA001"].conditions).client_app_types) == toset(["exchangeActiveSync", "other"])
    error_message = "CA001 blocks legacy clients only."
  }

  assert {
    condition     = toset(one(azuread_conditional_access_policy.baseline["CA002"].conditions).authentication_flow_transfer_methods) == toset(["deviceCodeFlow", "authenticationTransfer"])
    error_message = "CA002 blocks device code flow and authentication transfer."
  }
}

run "risk_policies_recheck_every_sign_in" {
  command = plan

  assert {
    condition = alltrue([for k in ["CA007", "CA008"] :
    one(azuread_conditional_access_policy.baseline[k].session_controls).sign_in_frequency_interval == "everyTime"])
    error_message = "Risk policies set sign-in frequency to every time, as Microsoft requires."
  }

  assert {
    condition = (
      one(azuread_conditional_access_policy.baseline["CA008"].grant_controls).operator == "AND" &&
      toset(one(azuread_conditional_access_policy.baseline["CA008"].grant_controls).built_in_controls) == toset(["mfa", "passwordChange"])
    )
    error_message = "High user risk needs MFA and a password change, both."
  }
}

run "untrusted_countries_include_unknown_ones" {
  command = plan

  assert {
    condition = (
      one(azuread_named_location.trusted_countries.country).countries_and_regions == tolist(["AU"]) &&
      one(azuread_named_location.trusted_countries.country).include_unknown_countries_and_regions == false
    )
    error_message = "Only Australia is trusted, and a sign-in that cannot be placed is not."
  }
}

run "a_missing_exclusion_group_stops_the_plan" {
  command = plan

  override_data {
    target          = data.tfe_outputs.privileged
    override_during = plan
    values = {
      nonsensitive_values = {}
    }
  }

  expect_failures = [azuread_conditional_access_policy.baseline]
}
