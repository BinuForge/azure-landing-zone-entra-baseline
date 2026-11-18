# Runs with mock providers: no sign-in, no network calls, nothing created.
mock_provider "azurerm" {
  mock_resource "azurerm_resource_group" {
    defaults = {
      id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/mock"
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

mock_provider "azapi" {
  # What Azure stores for the default management group: its short name (governance.tf check).
  mock_data "azapi_resource" {
    defaults = {
      output = { properties = { defaultManagementGroup = "lab-mg-sandbox" } }
    }
  }
}

variables {
  subscription_id            = "00000000-0000-0000-0000-000000000000"
  budget_contact_emails      = ["alerts@example.com"]
  github_oidc_subject_prefix = "repo:example@1/repo@2"
  hcp_organization           = "example-org"
}

run "one_plan_and_one_apply_identity_per_level_plus_the_runner" {
  command = plan

  assert {
    condition     = length(azuread_application.pipeline) == 11
    error_message = "Expected 11 identities: plan and apply for levels 0-4, and the ops agent runner."
  }

  assert {
    condition     = alltrue([for app in azuread_application.pipeline : can(regex("^lab-azure-l[0-4]-([a-z]+-)?(plan|apply|run)$", app.display_name))])
    error_message = "An identity name does not follow docs/naming.md."
  }
}

run "identities_are_single_tenant" {
  command = plan

  assert {
    condition     = alltrue([for app in azuread_application.pipeline : app.sign_in_audience == "AzureADMyOrg"])
    error_message = "Pipeline identities must only be usable in this tenant."
  }
}

run "github_subjects_pin_immutable_repo_and_environment" {
  command = plan

  assert {
    condition     = alltrue([for c in azuread_application_federated_identity_credential.github : startswith(c.subject, "repo:example@1/repo@2:environment:lab-azure-")])
    error_message = "GitHub subjects must use the immutable repository prefix and an environment, never a branch."
  }

  assert {
    condition     = !contains(keys(azuread_application_federated_identity_credential.github), "azure-l4-plan")
    error_message = "Level 4 runs in HCP Terraform, so it must not trust GitHub."
  }
}

run "level_4_trusts_hcp_per_workspace_and_phase" {
  command = plan

  assert {
    condition     = azuread_application_federated_identity_credential.hcp["azure-l4-apply/opsagent"].subject == "organization:example-org:project:lab-azure-workloads:workspace:lab-azure-l4-opsagent-np:run_phase:apply"
    error_message = "The level 4 apply identity must trust only the opsagent workspace's apply phase."
  }

  assert {
    condition     = alltrue([for c in azuread_application_federated_identity_credential.hcp : !strcontains(c.subject, "*")])
    error_message = "HCP subjects must be exact, with no wildcards."
  }
}

run "every_credential_uses_the_token_exchange_audience" {
  command = plan

  assert {
    condition = alltrue(concat(
      [for c in azuread_application_federated_identity_credential.github : length(c.audiences) == 1 && contains(c.audiences, "api://AzureADTokenExchange")],
      [for c in azuread_application_federated_identity_credential.hcp : length(c.audiences) == 1 && contains(c.audiences, "api://AzureADTokenExchange")],
    ))
    error_message = "Every federated credential must use the api://AzureADTokenExchange audience."
  }
}

run "branch_based_github_prefix_is_rejected" {
  command = plan

  variables {
    github_oidc_subject_prefix = "repo:example/repo:ref:refs/heads/main"
  }

  expect_failures = [var.github_oidc_subject_prefix]
}

run "gateway_grants_ai_invoke_to_the_runner_only" {
  command = plan

  assert {
    condition     = one(azuread_application.gateway.app_role).value == "AI.Invoke" && one(azuread_application.gateway.app_role).allowed_member_types == toset(["Application"])
    error_message = "The gateway must define one application role, AI.Invoke."
  }

  assert {
    condition     = keys(azuread_app_role_assignment.gateway_invoke) == ["azure-l4-opsagent-run"]
    error_message = "Only the ops agent runner may call the AI gateway."
  }

  assert {
    condition     = azuread_service_principal.gateway.app_role_assignment_required == true
    error_message = "Unassigned identities must not be able to get a token for the gateway."
  }

  assert {
    condition     = one(azuread_application.gateway.identifier_uris) == "api://00000000-0000-0000-0000-000000000002/lab-aigateway"
    error_message = "The gateway identifier must be tenant-scoped, so level 3 can build the same audience."
  }
}
