locals {
  # One GitHub environment per GitHub-federated identity, with the same name (docs/naming.md).
  github_environments = {
    for key, c in local.github_credentials : "${var.prefix}-${key}" => {
      identity = key
      phase    = local.identities[key].phase
    }
  }

  # Level 4 runs in HCP Terraform with dynamic credentials (ADR-0012). Its environments only start those
  # runs, so they carry the HCP token (set-pipeline-secrets.sh) and no Azure identity at all.
  hcp_environments = {
    for phase in ["plan", "apply"] : "${var.prefix}-azure-${local.workload_level}-${phase}" => { phase = phase }
  }

  environments = merge(local.github_environments, local.hcp_environments)

  # Plan environments accept any branch in this repository, so pull requests can plan. Apply and run
  # environments accept main only. Forks never receive environment secrets.
  main_only_environments = { for name, e in local.environments : name => e if e.phase != "plan" }
  reviewed_environments  = { for name, e in local.environments : name => e if e.phase == "apply" }
}

data "github_user" "apply_reviewer" {
  username = var.github_apply_reviewer
}

resource "github_repository_environment" "this" {
  for_each = local.environments

  repository          = var.github_repository
  environment         = each.key
  prevent_self_review = false # One maintainer approves their own applies (ADR-0006)
  can_admins_bypass   = false

  dynamic "reviewers" {
    for_each = contains(keys(local.reviewed_environments), each.key) ? [1] : []
    content {
      users = [data.github_user.apply_reviewer.id]
    }
  }

  dynamic "deployment_branch_policy" {
    for_each = contains(keys(local.main_only_environments), each.key) ? [1] : []
    content {
      protected_branches     = false
      custom_branch_policies = true
    }
  }
}

resource "github_repository_environment_deployment_policy" "main" {
  for_each = local.main_only_environments

  repository     = var.github_repository
  environment    = github_repository_environment.this[each.key].environment
  branch_pattern = "main"
}

# Client IDs and the organisation name are not sensitive.
resource "github_actions_environment_variable" "client_id" {
  for_each = local.github_environments

  repository    = var.github_repository
  environment   = github_repository_environment.this[each.key].environment
  variable_name = "AZURE_CLIENT_ID"
  value         = azuread_application.pipeline[each.value.identity].client_id
}

resource "github_actions_environment_variable" "tf_cloud_organization" {
  for_each = local.environments

  repository    = var.github_repository
  environment   = github_repository_environment.this[each.key].environment
  variable_name = "TF_CLOUD_ORGANIZATION"
  value         = var.hcp_organization
}

# Tenant and subscription IDs are identifiers, not credentials, so they may sit in bootstrap state. They
# are stored as secrets because variable values are printed in Actions logs, which are public here.
resource "github_actions_environment_secret" "tenant_id" {
  for_each = local.github_environments

  repository  = var.github_repository
  environment = github_repository_environment.this[each.key].environment
  secret_name = "AZURE_TENANT_ID"
  value       = data.azuread_client_config.current.tenant_id
}

resource "github_actions_environment_secret" "subscription_id" {
  for_each = local.github_environments

  repository  = var.github_repository
  environment = github_repository_environment.this[each.key].environment
  secret_name = "AZURE_SUBSCRIPTION_ID"
  value       = var.subscription_id
}
