# Level 0's published outputs (ADR-0013), from the reads list in tfc/workspaces.yaml.
data "tfe_outputs" "org" {
  workspace = "${var.prefix}-entra-l0-org-prd"
}

data "tfe_outputs" "privileged" {
  workspace = "${var.prefix}-entra-l0-privileged-prd"
}

locals {
  personas = data.tfe_outputs.org.nonsensitive_values.persona_group_ids

  # Every policy excludes this group, and nothing else (ADR-0017). A missing value would leave the
  # break-glass accounts inside every policy, so the policies check it before they are created.
  breakglass_group_id = try(data.tfe_outputs.privileged.nonsensitive_values.breakglass_exclusion_group_id, "")

  guid = "^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$"

  # Microsoft's list for "Require phishing-resistant multifactor authentication for administrators", by
  # role template ID. Targeting roles, not a group, also covers roles activated through PIM. Checked
  # against GET /directoryRoleTemplates on 2026-11-19.
  admin_roles = {
    "Global Administrator"                    = "62e90394-69f5-4237-9190-012177145e10"
    "Application Administrator"               = "9b895d92-2cd3-44c7-9d02-a6ac2d5ea5c3"
    "Authentication Administrator"            = "c4e39bd9-1100-46d3-8c65-fb160da0071f"
    "Billing Administrator"                   = "b0f54661-2d74-4c50-afa3-1ec803f12efe"
    "Cloud Application Administrator"         = "158c047a-c907-4556-b7ef-446551a6b5f7"
    "Conditional Access Administrator"        = "b1be1c3e-b65d-4f19-8427-f6fa0d97feb9"
    "Exchange Administrator"                  = "29232cdf-9323-42fd-ade2-1d097af3e4de"
    "Helpdesk Administrator"                  = "729827e3-9c14-49f7-bb1b-9608f156bbb8"
    "Password Administrator"                  = "966707d0-3269-4727-9be2-8c3a10f19b9d"
    "Privileged Authentication Administrator" = "7be44c8a-adaf-4e2a-84d6-ab2649e08a13"
    "Privileged Role Administrator"           = "e8611ab8-c189-46e8-94e1-60213ab1f814"
    "Security Administrator"                  = "194ae4cb-b126-40b2-bd5b-6091b380977d"
    "SharePoint Administrator"                = "f28a1f50-f6e7-4571-818b-6a12f2af6b6c"
    "User Administrator"                      = "fe930be7-5e62-47db-91af-98c3a49a38b1"
  }

  # Built-in authentication strength. Bank scale: a custom strength limited to approved FIDO2 models.
  phishing_resistant_mfa = "/policies/authenticationStrengthPolicies/00000000-0000-0000-0000-000000000004"

  # Every external user type except none and unknownFutureValue, as in Microsoft's guest MFA template.
  external_user_types = [
    "internalGuest",
    "b2bCollaborationGuest",
    "b2bCollaborationMember",
    "b2bDirectConnectUser",
    "otherExternalUser",
    "serviceProvider",
  ]
}
