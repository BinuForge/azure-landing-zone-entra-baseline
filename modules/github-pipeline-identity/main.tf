# One pipeline identity: an app registration that can only sign in with a GitHub OIDC token from one
# environment, and that environment with its branch rule, reviewer, variables and identifier secrets.
# Federated only: the app never has a secret or certificate (ADR-0012).

locals {
  subject = "${var.github_oidc_subject_prefix}:environment:${var.name}"
}

resource "azuread_application" "this" {
  display_name     = var.name
  description      = var.description
  sign_in_audience = "AzureADMyOrg"
  owners           = var.owner_object_ids
}

resource "azuread_service_principal" "this" {
  client_id = azuread_application.this.client_id
  owners    = var.owner_object_ids
}

resource "azuread_application_federated_identity_credential" "github" {
  # checkov:skip=CKV_AZURE_249:The check does not accept GitHub's immutable owner@id/repo@id form. The variable's validation and tests/module.tftest.hcl pin the subject to the immutable prefix and one environment.
  application_id = azuread_application.this.id
  display_name   = "github-${var.name}"
  description    = "GitHub Actions, environment ${var.name} only."
  issuer         = "https://token.actions.githubusercontent.com"
  subject        = local.subject
  audiences      = ["api://AzureADTokenExchange"]
}

resource "github_repository_environment" "this" {
  repository          = var.github_repository
  environment         = var.name
  prevent_self_review = false # One maintainer approves their own applies (ADR-0006)
  can_admins_bypass   = false

  dynamic "reviewers" {
    for_each = var.phase == "apply" ? [1] : []
    content {
      users = [var.reviewer_id]
    }
  }

  # Plans accept any branch in this repository, so pull requests can plan. Forks never receive
  # environment secrets.
  dynamic "deployment_branch_policy" {
    for_each = var.phase == "plan" ? [] : [1]
    content {
      protected_branches     = false
      custom_branch_policies = true
    }
  }
}

resource "github_repository_environment_deployment_policy" "main" {
  count = var.phase == "plan" ? 0 : 1

  repository     = var.github_repository
  environment    = github_repository_environment.this.environment
  branch_pattern = "main"
}

# Client IDs and the organisation name are not sensitive.
resource "github_actions_environment_variable" "client_id" {
  repository    = var.github_repository
  environment   = github_repository_environment.this.environment
  variable_name = "AZURE_CLIENT_ID"
  value         = azuread_application.this.client_id
}

resource "github_actions_environment_variable" "tf_cloud_organization" {
  repository    = var.github_repository
  environment   = github_repository_environment.this.environment
  variable_name = "TF_CLOUD_ORGANIZATION"
  value         = var.tf_cloud_organization
}

# Identifiers, not credentials, stored as secrets so they are masked in public logs.
resource "github_actions_environment_secret" "tenant_id" {
  repository  = var.github_repository
  environment = github_repository_environment.this.environment
  secret_name = "AZURE_TENANT_ID"
  value       = var.tenant_id
}

resource "github_actions_environment_secret" "subscription_id" {
  count = var.subscription_id == null ? 0 : 1

  repository  = var.github_repository
  environment = github_repository_environment.this.environment
  secret_name = "AZURE_SUBSCRIPTION_ID"
  value       = var.subscription_id
}
