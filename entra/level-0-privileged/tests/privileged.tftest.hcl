# Runs with mock providers: no sign-in, no network calls, nothing created.
mock_provider "azuread" {}
mock_provider "msgraph" {}

# Two healthy break-glass accounts, both Global Administrators.
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
    output = {
      ids = ["00000000-0000-0000-0000-0000000000b1", "00000000-0000-0000-0000-0000000000b2", "00000000-0000-0000-0000-0000000000c1"]
    }
  }
}

run "healthy_accounts_pass_and_join_the_exclusion_group" {
  command = plan

  assert {
    condition     = azuread_group.breakglass_exclusion.members == toset(["00000000-0000-0000-0000-0000000000b1", "00000000-0000-0000-0000-0000000000b2"])
    error_message = "The exclusion group holds exactly the two break-glass accounts."
  }

  assert {
    condition     = azuread_group.breakglass_exclusion.display_name == "lab-grp-excl-breakglass" && !azuread_group.breakglass_exclusion.assignable_to_role
    error_message = "The exclusion group follows docs/naming.md."
  }
}

run "the_unit_is_restricted_and_holds_both_accounts_and_the_group" {
  command = plan

  assert {
    condition     = msgraph_resource.emergency_au.body.isMemberManagementRestricted == true && msgraph_resource.emergency_au.body.displayName == "lab-au-emergency"
    error_message = "The unit must be a restricted management administrative unit; the setting cannot be added later."
  }

  assert {
    condition     = toset(keys(msgraph_resource.emergency_au_member)) == toset(["lab-emergency-01", "lab-emergency-02", "lab-grp-excl-breakglass"])
    error_message = "Both accounts and the exclusion group belong in the restricted unit."
  }
}

run "a_disabled_account_fails_the_plan" {
  command = plan

  override_data {
    target = data.msgraph_resource.breakglass
    values = {
      output = {
        users = [
          { id = "00000000-0000-0000-0000-0000000000b1", mailNickname = "lab-emergency-01", accountEnabled = false, onPremisesSyncEnabled = null, userType = "Member" },
          { id = "00000000-0000-0000-0000-0000000000b2", mailNickname = "lab-emergency-02", accountEnabled = true, onPremisesSyncEnabled = null, userType = "Member" },
        ]
      }
    }
  }

  expect_failures = [terraform_data.breakglass_checks]
}

run "a_look_alike_third_account_fails_the_plan" {
  command = plan

  override_data {
    target = data.msgraph_resource.breakglass
    values = {
      output = {
        users = [
          { id = "00000000-0000-0000-0000-0000000000b1", mailNickname = "lab-emergency-01", accountEnabled = true, onPremisesSyncEnabled = null, userType = "Member" },
          { id = "00000000-0000-0000-0000-0000000000b2", mailNickname = "lab-emergency-02", accountEnabled = true, onPremisesSyncEnabled = null, userType = "Member" },
          { id = "00000000-0000-0000-0000-0000000000b3", mailNickname = "lab-emergency-03", accountEnabled = true, onPremisesSyncEnabled = null, userType = "Member" },
        ]
      }
    }
  }

  expect_failures = [terraform_data.breakglass_checks]
}

run "an_account_synced_from_on_premises_fails_the_plan" {
  command = plan

  override_data {
    target = data.msgraph_resource.breakglass
    values = {
      output = {
        users = [
          { id = "00000000-0000-0000-0000-0000000000b1", mailNickname = "lab-emergency-01", accountEnabled = true, onPremisesSyncEnabled = true, userType = "Member" },
          { id = "00000000-0000-0000-0000-0000000000b2", mailNickname = "lab-emergency-02", accountEnabled = true, onPremisesSyncEnabled = null, userType = "Member" },
        ]
      }
    }
  }

  expect_failures = [terraform_data.breakglass_checks]
}

run "losing_global_administrator_fails_the_plan" {
  command = plan

  override_data {
    target = data.msgraph_resource.global_administrators
    values = {
      output = {
        ids = ["00000000-0000-0000-0000-0000000000b1"]
      }
    }
  }

  expect_failures = [terraform_data.breakglass_checks]
}
