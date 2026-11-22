# Runs with a mock provider: no sign-in, no network calls, nothing changed.
mock_provider "msgraph" {}

mock_provider "tfe" {}

# A tenant with passkey profiles, as current tenants return.
override_data {
  target = data.msgraph_resource.fido2
  values = {
    output = {
      profiles = [{ id = "00000000-0000-0000-0000-000000000001", passkeyTypes = "deviceBound,synced" }]
    }
  }
}

run "users_consent_to_nothing_and_create_nothing" {
  command = plan

  assert {
    condition     = msgraph_update_resource.authorization.body.defaultUserRolePermissions.permissionGrantPoliciesAssigned == []
    error_message = "No user consent policy is assigned: every app permission is an admin decision."
  }

  assert {
    condition = alltrue([for k in ["allowedToCreateApps", "allowedToCreateSecurityGroups", "allowedToCreateTenants"] :
    msgraph_update_resource.authorization.body.defaultUserRolePermissions[k] == false])
    error_message = "Users create no apps, security groups or tenants."
  }
}

run "guests_are_restricted_and_invited_by_admins" {
  command = plan

  assert {
    condition     = msgraph_update_resource.authorization.body.guestUserRoleId == "2af84b1e-32c8-42b7-82bc-daa82404023b"
    error_message = "Guests hold Restricted Guest User."
  }

  assert {
    condition     = msgraph_update_resource.authorization.body.allowInvitesFrom == "adminsAndGuestInviters"
    error_message = "Only admins and Guest Inviters invite guests."
  }

  assert {
    condition     = msgraph_update_resource.authorization.body.allowEmailVerifiedUsersToJoinOrganization == false
    error_message = "Nobody joins the tenant by verifying an email address."
  }
}

run "no_other_tenant_is_trusted" {
  command = plan

  assert {
    condition     = alltrue([for v in values(msgraph_update_resource.cross_tenant_default.body.inboundTrust) : v == false])
    error_message = "No other tenant's MFA or device claims are trusted."
  }

  assert {
    condition = alltrue([for k in ["b2bDirectConnectInbound", "b2bDirectConnectOutbound"] :
    msgraph_update_resource.cross_tenant_default.body[k].usersAndGroups.accessType == "blocked"])
    error_message = "Direct connect is blocked both ways."
  }
}

run "phishable_methods_are_off_and_passkeys_on" {
  command = plan

  assert {
    condition     = msgraph_update_resource.method["sms"].body.state == "disabled" && msgraph_update_resource.method["voice"].body.state == "disabled"
    error_message = "SMS and voice are off."
  }

  assert {
    condition     = msgraph_update_resource.method["microsoftAuthenticator"].body.isSoftwareOathEnabled == false
    error_message = "Authenticator gives no one-time codes."
  }

  assert {
    condition     = msgraph_update_resource.method["temporaryAccessPass"].body.isUsableOnce == true
    error_message = "A Temporary Access Pass works once."
  }

  assert {
    condition     = msgraph_update_resource.fido2.body.state == "enabled"
    error_message = "Passkeys are on."
  }
}

run "passkeys_are_device_bound_and_attested_with_profiles" {
  command = plan

  assert {
    condition = (
      one(msgraph_update_resource.fido2.body.passkeyProfiles).passkeyTypes == "deviceBound" &&
      one(msgraph_update_resource.fido2.body.passkeyProfiles).attestationEnforcement == "registrationOnly"
    )
    error_message = "With passkey profiles, passkeys are device-bound and attested at registration."
  }

  assert {
    condition     = !contains(keys(msgraph_update_resource.fido2.body), "isAttestationEnforced")
    error_message = "The deprecated property is not sent when profiles exist."
  }
}

run "a_tenant_without_profiles_gets_the_old_properties" {
  command = plan

  override_data {
    target = data.msgraph_resource.fido2
    values = {
      output = {}
    }
  }

  assert {
    condition = (
      msgraph_update_resource.fido2.body.isAttestationEnforced == true &&
      !contains(keys(msgraph_update_resource.fido2.body), "passkeyProfiles")
    )
    error_message = "Without profiles, attestation is enforced the old way and no profile is sent."
  }
}

run "consent_requests_go_to_the_pim_group" {
  command = plan

  override_data {
    target = data.tfe_outputs.privileged
    values = {
      nonsensitive_values = { cloudapp_admin_group_id = "00000000-0000-0000-0000-0000000000d1" }
    }
  }

  assert {
    condition = (
      length(msgraph_update_resource.admin_consent) == 1 &&
      msgraph_update_resource.admin_consent[0].body.isEnabled == true &&
      one(msgraph_update_resource.admin_consent[0].body.reviewers).query == "/groups/00000000-0000-0000-0000-0000000000d1/transitiveMembers"
    )
    error_message = "Requests are reviewed by the members of the PIM group, and no named person."
  }
}

run "no_consent_workflow_until_the_group_exists" {
  command = plan

  override_data {
    target = data.tfe_outputs.privileged
    values = {
      nonsensitive_values = {}
    }
  }

  assert {
    condition     = length(msgraph_update_resource.admin_consent) == 0
    error_message = "Requests are not enabled while nobody can review them."
  }
}
