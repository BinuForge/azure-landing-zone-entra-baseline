# Runs with mock providers: no sign-in, no network calls, nothing created.
mock_provider "azuread" {}
mock_provider "github" {}

variables {
  name                       = "lab-entra-l1-ca-apply"
  description                = "Test identity."
  phase                      = "apply"
  owner_object_ids           = ["00000000-0000-0000-0000-000000000001"]
  github_oidc_subject_prefix = "repo:example@1/repo@2"
  github_repository          = "repo"
  reviewer_id                = 12345
  tenant_id                  = "00000000-0000-0000-0000-000000000002"
  tf_cloud_organization      = "example-org"
}

run "apply_needs_a_reviewer_and_main" {
  command = plan

  assert {
    condition     = length(github_repository_environment.this.reviewers) == 1 && github_repository_environment_deployment_policy.main[0].branch_pattern == "main"
    error_message = "An apply environment must wait for a reviewer and accept main only."
  }

  assert {
    condition     = azuread_application_federated_identity_credential.github.subject == "repo:example@1/repo@2:environment:lab-entra-l1-ca-apply"
    error_message = "The identity must trust one environment of the immutable repository, never a branch."
  }

  assert {
    condition     = azuread_application.this.sign_in_audience == "AzureADMyOrg" && azuread_application_federated_identity_credential.github.audiences == tolist(["api://AzureADTokenExchange"])
    error_message = "Single tenant, and the token exchange audience only."
  }

  assert {
    condition     = length(github_actions_environment_secret.subscription_id) == 0
    error_message = "No subscription ID unless one is given."
  }
}

run "plan_accepts_any_branch_without_a_reviewer" {
  command = plan

  variables {
    name  = "lab-entra-l1-ca-plan"
    phase = "plan"
  }

  assert {
    condition     = length(github_repository_environment.this.reviewers) == 0 && length(github_repository_environment_deployment_policy.main) == 0
    error_message = "Plan environments accept pull request branches and wait for nobody."
  }
}

run "run_identities_accept_main_without_a_reviewer" {
  command = plan

  variables {
    name            = "lab-azure-l4-opsagent-run"
    phase           = "run"
    subscription_id = "00000000-0000-0000-0000-000000000000"
  }

  assert {
    condition     = length(github_repository_environment.this.reviewers) == 0 && length(github_repository_environment_deployment_policy.main) == 1
    error_message = "Run environments accept main only."
  }

  assert {
    condition     = length(github_actions_environment_secret.subscription_id) == 1
    error_message = "The subscription ID is stored when given."
  }
}

run "branch_based_subject_prefix_is_rejected" {
  command = plan

  variables {
    github_oidc_subject_prefix = "repo:example/repo:ref:refs/heads/main"
  }

  expect_failures = [var.github_oidc_subject_prefix]
}
