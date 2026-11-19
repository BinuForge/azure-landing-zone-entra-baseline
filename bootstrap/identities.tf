locals {
  # Levels come from the same YAML as the HCP workspaces, so a new level gets identities by adding it there.
  tfc_config     = yamldecode(file("${path.module}/../tfc/workspaces.yaml"))
  azure_levels   = distinct([for ws in local.tfc_config.workspaces : ws.level if ws.area == "azure"])
  workload_level = "l4"

  # One plan and one apply identity per level (docs/naming.md). Levels 0-3 run on GitHub Actions;
  # level 4 runs in HCP Terraform with dynamic credentials (ADR-0012).
  pipeline_identities = merge([
    for level in local.azure_levels : {
      for phase in ["plan", "apply"] : "azure-${level}-${phase}" => {
        level  = level
        phase  = phase
        issuer = level == local.workload_level ? "hcp" : "github"
      }
    }
  ]...)

  # The ops agent's runner is not a pipeline identity: it reads the estate at run time (threat model C-06).
  runtime_identities = {
    "azure-l4-opsagent-run" = { level = "l4", phase = "run", issuer = "github" }
  }

  identities = merge(local.pipeline_identities, local.runtime_identities)

  issuers = {
    github = "https://token.actions.githubusercontent.com"
    hcp    = "https://app.terraform.io"
  }
  token_audience = "api://AzureADTokenExchange"

  # GitHub: one credential per identity, pinned to the environment of the same name. The subject uses the
  # repository's immutable IDs, so a renamed or recreated repository cannot reuse it.
  github_credentials = {
    for key, id in local.identities : key => {
      identity = key
      subject  = "${var.github_oidc_subject_prefix}:environment:${var.prefix}-${key}"
    } if id.issuer == "github"
  }

  # HCP: one credential per level 4 workspace and run phase. Exact subjects, no wildcards.
  hcp_credentials = merge([
    for ws in local.tfc_config.workspaces : {
      for phase in ["plan", "apply"] : "azure-${ws.level}-${phase}/${ws.component}" => {
        identity = "azure-${ws.level}-${phase}"
        subject  = "organization:${var.hcp_organization}:project:${var.prefix}-${ws.project}:workspace:${var.prefix}-${ws.area}-${ws.level}-${ws.component}-${ws.env}:run_phase:${phase}"
      }
    } if ws.area == "azure" && ws.level == local.workload_level
  ]...)
}

data "azuread_client_config" "current" {}

resource "azuread_application" "pipeline" {
  for_each = local.identities

  display_name     = "${var.prefix}-${each.key}"
  description      = "${each.value.phase == "run" ? "Runtime" : "Pipeline"} identity for ${var.prefix}-azure-${each.value.level} (${each.value.phase}). Created by bootstrap, ADR-0012. Federated only: never add a secret."
  sign_in_audience = "AzureADMyOrg"
  owners           = [data.azuread_client_config.current.object_id]
}

resource "azuread_service_principal" "pipeline" {
  for_each = local.identities

  client_id = azuread_application.pipeline[each.key].client_id
  owners    = [data.azuread_client_config.current.object_id]
}

resource "azuread_application_federated_identity_credential" "github" {
  # checkov:skip=CKV_AZURE_249:Subject is computed, and the check does not accept GitHub's immutable owner@id/repo@id form. tests/identities.tftest.hcl asserts the prefix is immutable and every subject is pinned to one environment.
  for_each = local.github_credentials

  application_id = azuread_application.pipeline[each.value.identity].id
  display_name   = "github-${var.prefix}-${each.key}"
  description    = "GitHub Actions, environment ${var.prefix}-${each.key} only."
  issuer         = local.issuers.github
  subject        = each.value.subject
  audiences      = [local.token_audience]
}

resource "azuread_application_federated_identity_credential" "hcp" {
  # checkov:skip=CKV_AZURE_249:A GitHub Actions check; this issuer is HCP Terraform. tests/identities.tftest.hcl asserts every subject names one workspace and one run phase with no wildcards.
  for_each = local.hcp_credentials

  application_id = azuread_application.pipeline[each.value.identity].id
  display_name   = "hcp-${replace(each.key, "/", "-")}"
  description    = "HCP Terraform dynamic credentials, one workspace and run phase only."
  issuer         = local.issuers.hcp
  subject        = each.value.subject
  audiences      = [local.token_audience]
}
