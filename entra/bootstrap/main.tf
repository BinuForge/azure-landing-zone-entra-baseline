locals {
  # Workspaces come from the same YAML as HCP's, so a new Entra workspace gets identities by adding it there.
  tfc_config = yamldecode(file("${path.module}/../../tfc/workspaces.yaml"))

  # Entra workspaces that hold Tier 0 objects. Anything able to change them can make itself Global
  # Administrator, so CI only plans them and the maintainer applies them by hand (ADR-0016, decision 1).
  maintainer_applied = ["entra-l0-privileged"]

  # One pair per workspace, not per level, because their Graph permissions do not overlap (ADR-0016,
  # decision 3). Keyed like entra-l1-ca-apply; Tier 0 workspaces get a plan identity only.
  identities = merge([
    for ws in local.tfc_config.workspaces : {
      for phase in ["plan", "apply"] : "entra-${ws.level}-${ws.component}-${phase}" => {
        workspace = "entra-${ws.level}-${ws.component}"
        phase     = phase
      } if !(phase == "apply" && contains(local.maintainer_applied, "entra-${ws.level}-${ws.component}"))
    } if ws.area == "entra"
  ]...)

  # Workspaces whose apply identity must own what it creates, because its Graph permission manages only
  # owned objects (Group.Create). A saved plan fixes the owner when the plan identity makes it, so both
  # environments hold the apply identity's object ID.
  owning_workspaces = ["entra-l0-org"]
  apply_object_ids = merge([
    for ws in local.owning_workspaces : {
      for phase in ["plan", "apply"] : "${ws}-${phase}" => module.identity["${ws}-apply"].object_id
    }
  ]...)
}

data "azuread_client_config" "current" {}

data "github_user" "apply_reviewer" {
  username = var.github_apply_reviewer
}

# Entra environments hold no subscription ID: the Entra levels manage no Azure resources.
module "identity" {
  source   = "../../modules/github-pipeline-identity"
  for_each = local.identities

  name        = "${var.prefix}-${each.key}"
  description = "Pipeline identity for ${var.prefix}-${each.value.workspace} (${each.value.phase}). Created by entra/bootstrap, ADR-0016. Federated only: never add a secret."
  phase       = each.value.phase

  owner_object_ids           = [data.azuread_client_config.current.object_id]
  github_oidc_subject_prefix = var.github_oidc_subject_prefix
  github_repository          = var.github_repository
  reviewer_id                = data.github_user.apply_reviewer.id
  tenant_id                  = data.azuread_client_config.current.tenant_id
  tf_cloud_organization      = var.hcp_organization
}

# An identifier, stored as a secret so it is masked in public logs. Read as TF_VAR_apply_object_id.
resource "github_actions_environment_secret" "apply_object_id" {
  for_each = local.apply_object_ids

  repository  = var.github_repository
  environment = module.identity[each.key].environment
  secret_name = "APPLY_OBJECT_ID"
  value       = each.value
}
