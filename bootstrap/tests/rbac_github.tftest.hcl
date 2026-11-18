# Runs with mock providers: no sign-in, no network calls, nothing created.
mock_provider "azurerm" {
  override_during = plan

  mock_resource "azurerm_resource_group" {
    defaults = {
      id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/mock"
    }
  }
  mock_resource "azurerm_role_definition" {
    defaults = {
      role_definition_resource_id = "/subscriptions/00000000-0000-0000-0000-000000000000/providers/Microsoft.Authorization/roleDefinitions/00000000-0000-0000-0000-0000000000aa"
      role_definition_id          = "00000000-0000-0000-0000-0000000000aa"
    }
  }
}

mock_provider "azuread" {
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

mock_provider "azapi" {}

variables {
  subscription_id            = "00000000-0000-0000-0000-000000000000"
  budget_contact_emails      = ["alerts@example.com"]
  github_oidc_subject_prefix = "repo:example@1/repo@2"
  hcp_organization           = "example-org"
}

# Custom-role assignments are skipped: their name is computed, and the custom role's actions are
# checked separately below.
run "no_identity_is_owner_or_user_access_administrator" {
  command = plan

  assert {
    condition     = alltrue([for k, ra in azurerm_role_assignment.pipeline : !contains(["Owner", "User Access Administrator"], ra.role_definition_name) if !strcontains(k, "/spoke-join/")])
    error_message = "No pipeline identity may hold Owner or User Access Administrator (ADR-0012)."
  }
}

run "every_role_assignment_admin_is_constrained" {
  command = plan

  assert {
    condition = alltrue([
      for k, ra in azurerm_role_assignment.pipeline : ra.role_definition_name == azurerm_role_definition.role_assigner.name && ra.condition != null && ra.condition_version == "2.0"
      if strcontains(k, "/role-assigner/")
    ])
    error_message = "Every role assigner assignment must carry a condition."
  }

  assert {
    condition = alltrue([
      for k, ra in azurerm_role_assignment.pipeline :
      !strcontains(ra.condition, "8e3af657-a8ff-443c-a75c-2fe8c4bcb635") && !strcontains(ra.condition, "18d7d88d-d35e-4fb5-a5c3-7773c20a72d9")
      if strcontains(k, "/role-assigner/")
    ])
    error_message = "A delegation condition must never allow Owner or User Access Administrator."
  }

  assert {
    condition     = strcontains(azurerm_role_assignment.pipeline["azure-l3-apply/role-assigner/aiservices"].condition, "'ServicePrincipal'")
    error_message = "Delegated role assignment must be limited to service principals."
  }

  # On the management group, level 3 may grant Log Analytics Reader only: never the model role.
  assert {
    condition = (
      strcontains(azurerm_role_assignment.pipeline["azure-l3-apply/role-assigner/management"].condition, "73c42c96-874c-492b-b04d-ab87d138a893")
      && !strcontains(azurerm_role_assignment.pipeline["azure-l3-apply/role-assigner/management"].condition, "5e0bd9bd-7b93-4f28-af87-19fc36ad61bd")
    )
    error_message = "Level 3's management delegation must allow Log Analytics Reader and nothing else."
  }
}

run "only_levels_0_and_1_reach_the_root" {
  command = plan

  assert {
    condition = alltrue([
      for k, ra in azurerm_role_assignment.pipeline : can(regex("^azure-l[01]-", k))
      if startswith(ra.scope, "/providers/Microsoft.Management/managementGroups/")
    ])
    error_message = "Only levels 0 and 1 may hold roles at the root management group."
  }
}

run "log_linker_holds_only_the_linking_actions" {
  command = plan

  assert {
    condition = toset(one(azurerm_role_definition.log_linker.permissions).actions) == toset([
      "Microsoft.OperationalInsights/workspaces/read",
      "Microsoft.OperationalInsights/workspaces/sharedKeys/action",
    ])
    error_message = "The log linker role must hold only what diagnostic settings need."
  }

  assert {
    condition     = keys(azurerm_role_assignment.log_linker) == ["azure-l3-apply"]
    error_message = "Only levels that send diagnostics to the ops workspace get the log linker role."
  }
}

run "purger_can_only_purge_soft_deleted_services" {
  command = plan

  assert {
    condition     = alltrue([for a in one(azurerm_role_definition.soft_delete_purger.permissions).actions : !strcontains(a, "*") && (strcontains(a, "/deletedservices/") || strcontains(a, "/deletedAccounts/"))])
    error_message = "The purger may act on soft-deleted APIM services and AI accounts only."
  }

  assert {
    condition     = keys(azurerm_role_assignment.soft_delete_purger) == ["azure-l3-apply"]
    error_message = "Only level 3 creates services that need purging."
  }
}

run "no_pipeline_identity_reads_log_data" {
  command = plan

  assert {
    condition = alltrue([for r in [
      azurerm_role_definition.config_reader,
      azurerm_role_definition.role_assigner,
      azurerm_role_definition.policy_writer,
      ] : contains(one(r.permissions).actions, "*/read") && alltrue([for a in [
        "Microsoft.OperationalInsights/workspaces/query/*",
        "Microsoft.OperationalInsights/workspaces/tables/query/read",
        "Microsoft.OperationalInsights/workspaces/search/read",
        "Microsoft.Insights/logs/*",
        "Microsoft.Insights/components/query/read",
    ] : contains(one(r.permissions).not_actions, a)])])
    error_message = "Every custom role with */read must remove the Log Analytics and Application Insights log reads."
  }

  assert {
    condition     = toset(one(azurerm_role_definition.config_reader.permissions).actions) == toset(["*/read"])
    error_message = "The config reader must read and nothing else."
  }

  assert {
    condition     = alltrue([for k, ra in azurerm_role_assignment.pipeline : ra.role_definition_name == azurerm_role_definition.config_reader.name if strcontains(k, "-plan/")])
    error_message = "Every plan identity must hold the config reader."
  }

  # These built-ins include */read, which covers Log Analytics queries.
  assert {
    condition = !anytrue([
      for k, ra in azurerm_role_assignment.pipeline :
      contains(["Reader", "Role Based Access Control Administrator", "Resource Policy Contributor"], ra.role_definition_name)
      if !strcontains(k, "/spoke-join/")
    ])
    error_message = "No pipeline identity may hold Reader, Role Based Access Control Administrator or Resource Policy Contributor: use the custom twins."
  }
}

run "no_level_can_grant_read_on_the_prompt_workspace" {
  command = plan

  assert {
    condition = alltrue([
      for k, ra in azurerm_role_assignment.pipeline : !strcontains(ra.condition, "73c42c96-874c-492b-b04d-ab87d138a893")
      if strcontains(k, "/role-assigner/") && !endswith(k, "/management")
    ])
    error_message = "Log Analytics Reader may be delegated on the management group only, never where the prompt workspace lives (ADR-0010)."
  }

  assert {
    condition = (
      strcontains(azurerm_role_assignment.pipeline["azure-l4-apply/role-assigner/subscription"].condition, azurerm_role_definition.config_reader.role_definition_id)
      && strcontains(azurerm_role_assignment.pipeline["azure-l4-apply/role-assigner/management"].condition, azurerm_role_definition.log_reader.role_definition_id)
    )
    error_message = "Level 4 grants the runner the config reader at subscription and the log reader on the management group only."
  }
}

run "runner_roles_cannot_open_support_requests" {
  command = plan

  assert {
    condition = alltrue([for r in [azurerm_role_definition.cost_reader, azurerm_role_definition.log_reader] :
    !anytrue([for a in one(r.permissions).actions : startswith(lower(a), "microsoft.support/") || a == "*"])])
    error_message = "The runner's readers must not include Microsoft.Support/*: opening a support request is a write (T-02)."
  }

  assert {
    condition = alltrue([for r in [azurerm_role_definition.cost_reader, azurerm_role_definition.log_reader] :
    alltrue([for a in one(r.permissions).actions : endswith(a, "/read") || endswith(a, "/query/action") || endswith(a, "/search/action")])])
    error_message = "The runner's readers may only read and query."
  }

  # Level 4 may still remove the built-ins it granted before, but may no longer grant them.
  assert {
    condition = alltrue([for k in ["azure-l4-apply/role-assigner/subscription", "azure-l4-apply/role-assigner/management"] :
      !strcontains(split("roleAssignments/delete", azurerm_role_assignment.pipeline[k].condition)[0], "72fafb9e-0641-4937-9268-a91bfd8191a3") &&
      !strcontains(split("roleAssignments/delete", azurerm_role_assignment.pipeline[k].condition)[0], "73c42c96-874c-492b-b04d-ab87d138a893")
    ])
    error_message = "Level 4 must not be able to grant Cost Management Reader or Log Analytics Reader any more."
  }

  # Until level 4 has swapped them, it must still be able to remove its old grants. Remove this assert
  # when the retiring list is emptied.
  assert {
    condition = (
      strcontains(split("roleAssignments/delete", azurerm_role_assignment.pipeline["azure-l4-apply/role-assigner/subscription"].condition)[1], "72fafb9e-0641-4937-9268-a91bfd8191a3")
      && strcontains(split("roleAssignments/delete", azurerm_role_assignment.pipeline["azure-l4-apply/role-assigner/management"].condition)[1], "73c42c96-874c-492b-b04d-ab87d138a893")
    )
    error_message = "Level 4 must be able to remove the built-in readers it granted before (retiring)."
  }
}

run "assignments_are_typed_as_service_principals" {
  command = plan

  assert {
    condition     = alltrue([for ra in azurerm_role_assignment.pipeline : ra.principal_type == "ServicePrincipal"])
    error_message = "Every assignment must declare principal_type ServicePrincipal."
  }
}

run "spoke_join_role_has_no_wildcards_and_two_scopes" {
  command = plan

  assert {
    condition     = alltrue([for a in one(azurerm_role_definition.spoke_network_join.permissions).actions : !strcontains(a, "*")])
    error_message = "The custom role must list exact actions, never wildcards."
  }

  assert {
    condition     = length(azurerm_role_definition.spoke_network_join.assignable_scopes) == 2
    error_message = "The custom role must be assignable only to the connectivity and DNS groups."
  }
}

run "apply_environments_need_review_and_main" {
  command = plan

  assert {
    condition     = length(github_repository_environment.this) == 11
    error_message = "Expected one environment per GitHub-federated identity, plus level 4 plan and apply."
  }

  assert {
    condition     = alltrue([for name, env in github_repository_environment.this : length(env.reviewers) == 1 if endswith(name, "-apply")])
    error_message = "Every apply environment must require a reviewer."
  }

  assert {
    condition     = alltrue([for name, env in github_repository_environment.this : length(env.reviewers) == 0 if endswith(name, "-plan")])
    error_message = "Plan environments must not wait for a reviewer."
  }

  assert {
    condition     = alltrue([for p in github_repository_environment_deployment_policy.main : p.branch_pattern == "main"])
    error_message = "Apply and run environments must accept main only."
  }

  assert {
    condition     = !contains(keys(github_repository_environment_deployment_policy.main), "lab-azure-l0-plan")
    error_message = "Plan environments must accept pull request branches."
  }
}

run "level_4_environments_hold_no_azure_identity" {
  command = plan

  assert {
    condition     = contains(keys(github_repository_environment.this), "lab-azure-l4-apply") && length(github_repository_environment.this["lab-azure-l4-apply"].reviewers) == 1
    error_message = "Level 4 applies start from a reviewed GitHub environment."
  }

  assert {
    condition = alltrue([
      for name in ["lab-azure-l4-plan", "lab-azure-l4-apply"] :
      !contains(keys(github_actions_environment_variable.client_id), name) && !contains(keys(github_actions_environment_secret.tenant_id), name)
    ])
    error_message = "Level 4 authenticates to Azure through HCP Terraform, so its GitHub environments hold no Azure identity."
  }
}
