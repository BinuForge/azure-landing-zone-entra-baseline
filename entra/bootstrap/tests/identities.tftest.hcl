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
  github_owner               = "example"
  github_apply_reviewer      = "example"
}

run "one_identity_pair_per_entra_workspace_and_no_apply_for_tier_0" {
  command = plan

  assert {
    condition = toset(keys(module.identity)) == toset([
      "entra-l0-org-plan", "entra-l0-org-apply",
      "entra-l0-privileged-plan",
      "entra-l1-governance-plan", "entra-l1-governance-apply",
      "entra-l1-ca-plan", "entra-l1-ca-apply",
    ])
    error_message = "Each Entra workspace gets a plan and an apply identity, except level-0-privileged, which the maintainer applies."
  }

  assert {
    condition     = alltrue([for k, id in local.identities : id.phase == "plan" if startswith(k, "entra-l0-privileged-")])
    error_message = "No identity, and so no GitHub environment, may apply a Tier 0 workspace."
  }
}

run "names_follow_the_naming_convention" {
  command = plan

  assert {
    condition     = alltrue([for k, id in module.identity : id.environment == "lab-${k}" && can(regex("^lab-entra-l[01]-[a-z]+-(plan|apply)$", id.environment))])
    error_message = "Identity and environment share one name, lab-entra-<level>-<component>-<phase> (docs/naming.md)."
  }
}

run "branch_based_github_prefix_is_rejected" {
  command = plan

  variables {
    github_oidc_subject_prefix = "repo:example/repo:ref:refs/heads/main"
  }

  expect_failures = [var.github_oidc_subject_prefix]
}

run "level_0_org_environments_name_the_apply_identity_as_owner" {
  command = plan

  assert {
    condition     = toset(keys(github_actions_environment_secret.apply_object_id)) == toset(["entra-l0-org-plan", "entra-l0-org-apply"])
    error_message = "Both level 0 org environments, and only they, hold the apply identity's object ID."
  }

  assert {
    condition     = alltrue([for s in github_actions_environment_secret.apply_object_id : s.secret_name == "APPLY_OBJECT_ID"])
    error_message = "The workflows read the secret as APPLY_OBJECT_ID."
  }
}
