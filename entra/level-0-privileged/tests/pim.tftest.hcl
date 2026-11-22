# Runs with mock providers: no sign-in, no network calls, nothing created.
mock_provider "azuread" {}
mock_provider "msgraph" {}

override_data {
  target = data.msgraph_resource.breakglass
  values = {
    output = {
      users = [
        { id = "00000000-0000-0000-0000-0000000000b1", mailNickname = "lab-emergency-01", accountEnabled = true, onPremisesSyncEnabled = null, userType = "Member" },
        { id = "00000000-0000-0000-0000-0000000000b2", mailNickname = "lab-emergency-02", accountEnabled = true, onPremisesSyncEnabled = null, userType = "Member" },
      ]
    }
  }
}

override_data {
  target = data.msgraph_resource.global_administrators
  values = {
    output = { ids = ["00000000-0000-0000-0000-0000000000b1", "00000000-0000-0000-0000-0000000000b2"] }
  }
}

override_data {
  target = data.msgraph_resource.cloudapp_admin_group
  values = {
    output = { groups = [{ id = "00000000-0000-0000-0000-0000000000d1", isAssignableToRole = true }] }
  }
}

# A healthy PIM state: only break-glass hold standing Global Administrator, every role has an eligible
# principal, and activation rules match pim/pim.json.
override_data {
  target = data.msgraph_resource.ga_schedules
  values = {
    output = { standing = ["00000000-0000-0000-0000-0000000000b1", "00000000-0000-0000-0000-0000000000b2"] }
  }
}

override_data {
  target = data.msgraph_resource.eligibility
  values = {
    output = { roles = ["62e90394-69f5-4237-9190-012177145e10", "e8611ab8-c189-46e8-94e1-60213ab1f814", "194ae4cb-b126-40b2-bd5b-6091b380977d", "158c047a-c907-4556-b7ef-446551a6b5f7"] }
  }
}

override_data {
  target = data.msgraph_resource.ga_policy
  values = {
    output = {
      rules = [
        { id = "Expiration_EndUser_Assignment", maximumDuration = "PT4H" },
        { id = "Enablement_EndUser_Assignment", enabledRules = ["MultiFactorAuthentication", "Justification"] },
      ]
    }
  }
}

override_data {
  target = data.msgraph_resource.pra_policy
  values = {
    output = {
      rules = [
        { id = "Expiration_EndUser_Assignment", maximumDuration = "PT4H" },
        { id = "Enablement_EndUser_Assignment", enabledRules = ["MultiFactorAuthentication", "Justification"] },
      ]
    }
  }
}

override_data {
  target = data.msgraph_resource.secadmin_policy
  values = {
    output = {
      rules = [
        { id = "Expiration_EndUser_Assignment", maximumDuration = "PT8H" },
        { id = "Enablement_EndUser_Assignment", enabledRules = ["MultiFactorAuthentication", "Justification"] },
      ]
    }
  }
}

override_data {
  target = data.msgraph_resource.cloudapp_policy
  values = {
    output = {
      rules = [
        { id = "Expiration_EndUser_Assignment", maximumDuration = "PT8H" },
        { id = "Enablement_EndUser_Assignment", enabledRules = ["MultiFactorAuthentication", "Justification"] },
      ]
    }
  }
}

run "pim_json_is_tight" {
  command = plan

  assert {
    condition     = toset(keys(local.roles)) == toset(["Global Administrator", "Privileged Role Administrator", "Security Administrator", "Cloud Application Administrator"])
    error_message = "Each role in pim/pim.json needs its own activation check in pim.tf. Add the check, then this name."
  }

  assert {
    condition     = local.roles["Global Administrator"].maximumActivation == "PT4H" && local.roles["Privileged Role Administrator"].maximumActivation == "PT4H"
    error_message = "Tier 0 roles activate for four hours at most."
  }

  assert {
    condition     = alltrue([for r in values(local.roles) : contains(["PT1H", "PT2H", "PT4H", "PT8H"], r.maximumActivation)])
    error_message = "No role activates for more than eight hours."
  }

  assert {
    condition     = toset(local.pim.activationRules) == toset(["MultiFactorAuthentication", "Justification"])
    error_message = "Activation needs MFA and a justification."
  }

  assert {
    condition     = local.pim.eligibilityDuration == "P365D"
    error_message = "Eligible assignments expire after a year and are renewed on purpose."
  }

  assert {
    condition     = alltrue([for r in values(local.roles) : r.eligible == "maintainer" || contains(keys(local.pim.groups), r.eligible)])
    error_message = "A role is eligible for the maintainer or for a group defined in pim.json, nobody else."
  }
}

run "the_reviewer_group_is_published_only_if_role_assignable" {
  command = plan

  assert {
    condition     = output.cloudapp_admin_group_id == "00000000-0000-0000-0000-0000000000d1"
    error_message = "Level 1 governance reads the reviewer group's ID."
  }
}

run "a_plain_group_with_the_same_name_is_not_published" {
  command = plan

  override_data {
    target = data.msgraph_resource.cloudapp_admin_group
    values = {
      output = { groups = [{ id = "00000000-0000-0000-0000-0000000000d2", isAssignableToRole = false }] }
    }
  }

  assert {
    condition     = output.cloudapp_admin_group_id == null
    error_message = "A look-alike group that is not role-assignable is not a reviewer group."
  }
}

run "standing_global_administrator_outside_break_glass_is_flagged" {
  command = plan

  override_data {
    target = data.msgraph_resource.ga_schedules
    values = {
      output = { standing = ["00000000-0000-0000-0000-0000000000b1", "00000000-0000-0000-0000-0000000000b2", "00000000-0000-0000-0000-0000000000c1"] }
    }
  }

  expect_failures = [check.standing_global_administrator_is_break_glass_only]
}

run "a_longer_activation_than_pim_json_is_flagged" {
  command = plan

  override_data {
    target = data.msgraph_resource.ga_policy
    values = {
      output = { rules = [{ id = "Expiration_EndUser_Assignment", maximumDuration = "PT8H" }] }
    }
  }

  expect_failures = [check.global_administrator_activation]
}
