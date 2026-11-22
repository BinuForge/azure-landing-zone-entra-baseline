# Tenant-wide defaults for users and guests (ADR-0018). Each setting here is a singleton: Terraform
# manages these properties only, and removing the resource leaves them as they are.
locals {
  restricted_guest_role = "2af84b1e-32c8-42b7-82bc-daa82404023b" # Restricted Guest User, checked 2026-11-19
}

resource "msgraph_update_resource" "authorization" {
  url = "policies/authorizationPolicy"

  body = {
    # Only admins and the Guest Inviter role invite guests; guests see only their own objects.
    allowInvitesFrom = "adminsAndGuestInviters"
    guestUserRoleId  = local.restricted_guest_role

    # No self-service sign-up or tenant join through an email address.
    allowedToSignUpEmailBasedSubscriptions    = false
    allowEmailVerifiedUsersToJoinOrganization = false

    # Users create no apps, security groups or tenants, and consent to nothing: every app permission is
    # an admin decision. The object is replaced as a whole, so every property is set.
    defaultUserRolePermissions = {
      allowedToCreateApps                      = false
      allowedToCreateSecurityGroups            = false
      allowedToCreateTenants                   = false
      allowedToReadBitlockerKeysForOwnedDevice = false
      allowedToReadOtherUsers                  = true
      permissionGrantPoliciesAssigned          = []
    }
  }
}
