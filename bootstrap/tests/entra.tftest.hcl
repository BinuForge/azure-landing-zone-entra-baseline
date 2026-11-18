# Runs with mock providers: no sign-in, no network calls, nothing created. ADR-0016.
mock_provider "azurerm" {
  mock_resource "azurerm_resource_group" {
    defaults = {
      id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/mock"
    }
  }
}

mock_provider "azuread" {
  # Microsoft Graph's service principal in this tenant (entra.tf).
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

mock_provider "azapi" {
  mock_data "azapi_resource" {
    defaults = {
      output = { properties = { defaultManagementGroup = "lab-mg-sandbox" } }
    }
  }
}

# A known workspace ID at plan time, so a test can check where the diagnostic setting sends logs.
override_resource {
  target          = azurerm_log_analytics_workspace.security
  override_during = plan
  values = {
    id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/lab-rg-bootstrap-prd-ae/providers/Microsoft.OperationalInsights/workspaces/lab-log-security-prd-ae"
  }
}

variables {
  subscription_id            = "00000000-0000-0000-0000-000000000000"
  budget_contact_emails      = ["alerts@example.com"]
  github_oidc_subject_prefix = "repo:example@1/repo@2"
  hcp_organization           = "example-org"
}

run "one_identity_pair_per_entra_workspace_and_no_apply_for_tier_0" {
  command = plan

  assert {
    condition = toset([for k in keys(azuread_application.pipeline) : k if startswith(k, "entra-")]) == toset([
      "entra-l0-org-plan", "entra-l0-org-apply",
      "entra-l0-privileged-plan",
      "entra-l1-governance-plan", "entra-l1-governance-apply",
      "entra-l1-ca-plan", "entra-l1-ca-apply",
    ])
    error_message = "Each Entra workspace gets a plan and an apply identity, except level-0-privileged, which the maintainer applies."
  }

  assert {
    condition     = !contains(keys(github_repository_environment.this), "lab-entra-l0-privileged-apply")
    error_message = "No GitHub environment may unlock a Tier 0 apply."
  }

  assert {
    condition = alltrue([
      for name in ["lab-entra-l0-org-apply", "lab-entra-l1-governance-apply", "lab-entra-l1-ca-apply"] :
      length(github_repository_environment.this[name].reviewers) == 1 && contains(keys(github_repository_environment_deployment_policy.main), name)
    ])
    error_message = "Entra apply environments need a reviewer and accept main only, like Azure's."
  }

  assert {
    condition     = alltrue([for k in keys(github_actions_environment_secret.subscription_id) : !strcontains(k, "-entra-")])
    error_message = "Entra environments manage no Azure resources, so they hold no subscription ID."
  }
}

run "only_entra_identities_hold_graph_permissions_and_azure_roles_stay_azure" {
  command = plan

  assert {
    condition     = alltrue([for g in local.graph_grants : startswith(g.identity, "entra-")])
    error_message = "Only Entra identities may hold Graph permissions."
  }

  assert {
    condition     = alltrue([for a in local.role_assignments : !startswith(a.identity, "entra-")])
    error_message = "Entra identities hold no Azure roles."
  }

  assert {
    condition     = alltrue([for g in local.graph_grants : contains(keys(local.graph_permission_ids), g.permission)])
    error_message = "rbac.yaml names a Graph permission that entra.tf does not allow."
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
    error_message = "A Tier 0 Graph permission is in entra.tf's allowed list (ADR-0016, decision 3)."
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
    condition = toset([for g in local.graph_grants : g.permission if g.identity == "entra-l1-ca-apply"]) == toset([
      "Policy.Read.All", "Policy.ReadWrite.ConditionalAccess",
    ])
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

run "entra_logs_go_to_a_workspace_only_the_maintainer_reads" {
  command = plan

  assert {
    condition = (
      azurerm_log_analytics_workspace.security.resource_group_name == "lab-rg-bootstrap-prd-ae" &&
      azurerm_log_analytics_workspace.security.local_authentication_enabled == false &&
      azurerm_log_analytics_workspace.security.allow_resource_only_permissions == false
    )
    error_message = "The security workspace lives in bootstrap's group, with shared keys and resource-context access off."
  }

  # Roles at the root and subscription reach bootstrap's group too. The custom ones read no logs
  # (rbac_github.tftest.hcl), and Management Group Contributor acts on management groups only.
  assert {
    condition = alltrue([
      for k, a in local.role_assignments :
      split("/", k)[2] != "bootstrap" && (!contains(["root", "subscription"], split("/", k)[2]) || startswith(a.role, "custom:") || a.role == "Management Group Contributor")
    ])
    error_message = "No pipeline identity may hold a role that can read logs in bootstrap's group."
  }

  assert {
    condition     = length(azurerm_monitor_aad_diagnostic_setting.entra) == 0
    error_message = "Entra diagnostics stay off until the tenant has Entra ID P1 or P2."
  }
}

run "entra_diagnostics_send_sign_ins_and_audit_to_the_security_workspace" {
  command = plan

  variables {
    entra_diagnostics = true
  }

  assert {
    condition = (
      azurerm_monitor_aad_diagnostic_setting.entra[0].log_analytics_workspace_id == azurerm_log_analytics_workspace.security.id &&
      length(setintersection(toset([for l in azurerm_monitor_aad_diagnostic_setting.entra[0].enabled_log : l.category]), toset(["AuditLogs", "SignInLogs", "ServicePrincipalSignInLogs"]))) == 3
    )
    error_message = "Entra audit and sign-in logs, including service principal sign-ins, go to the security workspace."
  }
}
