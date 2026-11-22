# Default cross-tenant access (ADR-0018). Guest collaboration stays allowed, because invitations are
# already limited to admins. Direct connect stays blocked both ways, no other tenant's MFA or device
# claims are trusted, and no invitation is redeemed without the user's consent prompt.
locals {
  blocked_all = {
    usersAndGroups = { accessType = "blocked", targets = [{ target = "AllUsers", targetType = "user" }] }
    applications   = { accessType = "blocked", targets = [{ target = "AllApplications", targetType = "application" }] }
  }
  allowed_all = {
    usersAndGroups = { accessType = "allowed", targets = [{ target = "AllUsers", targetType = "user" }] }
    applications   = { accessType = "allowed", targets = [{ target = "AllApplications", targetType = "application" }] }
  }
}

resource "msgraph_update_resource" "cross_tenant_default" {
  url = "policies/crossTenantAccessPolicy/default"

  body = {
    b2bCollaborationInbound  = local.allowed_all
    b2bCollaborationOutbound = local.allowed_all
    b2bDirectConnectInbound  = local.blocked_all
    b2bDirectConnectOutbound = local.blocked_all

    inboundTrust = {
      isMfaAccepted                       = false
      isCompliantDeviceAccepted           = false
      isHybridAzureADJoinedDeviceAccepted = false
    }

    automaticUserConsentSettings = {
      inboundAllowed  = false
      outboundAllowed = false
    }
  }
}
