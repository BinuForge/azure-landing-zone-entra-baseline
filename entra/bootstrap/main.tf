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
