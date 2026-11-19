# Runs with mock providers: no sign-in, no network calls, nothing created. ADR-0016.
mock_provider "azuread" {
  # Microsoft Graph's service principal in this tenant (graph.tf).
  mock_data "azuread_service_principal" {
    defaults = {
      object_id = "00000000-0000-0000-0000-000000000003"
    }
  }
  mock_data "azuread_client_config" {
    defaults = {
      object_id = "00000000-0000-0000-0000-000000000001"
      tenant_id = "00000000-0000-0000-0000-000000000002"
    }
  }
}

mock_provider "github" {
  mock_data "github_user" {
    defaults = {
      id = "12345"
    }
  }
}

variables {
  github_oidc_subject_prefix = "repo:example@1/repo@2"
  hcp_organization           = "example-org"
}

run "every_grant_names_a_known_identity_and_an_allowed_permission" {
  command = plan

  assert {
    condition     = alltrue([for g in local.graph_grants : contains(keys(local.identities), g.identity)])
    error_message = "graph.yaml names an identity that main.tf does not create."
  }

  assert {
    condition     = alltrue([for g in local.graph_grants : contains(keys(local.graph_permission_ids), g.permission)])
    error_message = "graph.yaml names a Graph permission that graph.tf does not allow."
  }

  assert {
    condition     = length(azuread_app_role_assignment.graph) == 24
    error_message = "graph.yaml holds 24 grants (ADR-0016)."
  }
}

# Each of these can grant roles or app permissions, add credentials, change every group, or open consent,
# so a pipeline holding one could make itself Global Administrator or bypass Conditional Access.
run "no_tier_0_graph_permission_can_be_granted" {
  command = plan

  assert {
    condition = alltrue([for p in [
      "RoleManagement.ReadWrite.Directory",
      "RoleAssignmentSchedule.ReadWrite.Directory",
      "RoleEligibilitySchedule.ReadWrite.Directory",
      "RoleManagementPolicy.ReadWrite.Directory",
      "PrivilegedAccess.ReadWrite.AzureAD",
      "PrivilegedAccess.ReadWrite.AzureADGroup",
      "PrivilegedAssignmentSchedule.ReadWrite.AzureADGroup",
      "PrivilegedEligibilitySchedule.ReadWrite.AzureADGroup",
      "RoleManagementPolicy.ReadWrite.AzureADGroup",
      "AppRoleAssignment.ReadWrite.All",
      "Application.ReadWrite.All",
      "Application.ReadWrite.OwnedBy",
      "Directory.ReadWrite.All",
      "Group.ReadWrite.All",
      "GroupMember.ReadWrite.All",
      "AdministrativeUnit.ReadWrite.All",
      "User.ReadWrite.All",
      "UserAuthenticationMethod.ReadWrite.All",
      "Policy.ReadWrite.PermissionGrant",
      "Policy.ReadWrite.ApplicationConfiguration",
    ] : !contains(keys(local.graph_permission_ids), p)])
    error_message = "A Tier 0 Graph permission is in graph.tf's allowed list (ADR-0016, decision 4)."
  }

  assert {
    condition     = !contains(values(local.graph_permission_ids), "9e3f62cf-ca93-4989-b6ce-bf83c28f9fe8")
    error_message = "RoleManagement.ReadWrite.Directory must not appear under another name."
  }
}

run "plan_identities_only_read" {
  command = plan

  assert {
    condition = alltrue([
      for g in local.graph_grants : can(regex("\\.Read(Basic)?\\.", g.permission))
      if endswith(g.identity, "-plan")
    ])
    error_message = "A plan identity holds a Graph permission that writes."
  }
}

run "each_apply_identity_writes_only_its_own_area" {
  command = plan

  assert {
    condition     = toset([for g in local.graph_grants : g.permission if g.identity == "entra-l1-ca-apply"]) == toset(["Policy.Read.All", "Policy.ReadWrite.ConditionalAccess"])
    error_message = "The Conditional Access identity holds exactly the two permissions Microsoft documents."
  }

  assert {
    condition     = toset([for g in local.graph_grants : g.permission if g.identity == "entra-l0-org-apply"]) == toset(["Group.Create", "Group.Read.All", "User.Read.All"])
    error_message = "The org identity creates groups it owns; it never changes other groups."
  }

  assert {
    condition = alltrue([
      for g in local.graph_grants : !strcontains(g.permission, "ConditionalAccess")
      if g.identity != "entra-l1-ca-apply" && strcontains(g.permission, "ReadWrite")
    ])
    error_message = "Only the Conditional Access identity may write Conditional Access."
  }

  assert {
    condition     = azuread_app_role_assignment.graph["entra-l1-ca-apply/Policy.ReadWrite.ConditionalAccess"].app_role_id == "01c0a623-fc9b-48e9-b794-0756f8e8f067"
    error_message = "Permissions are granted by their Graph ID."
  }
}
