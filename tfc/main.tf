locals {
  config = yamldecode(file("${path.module}/${var.config_file}"))

  # Key is the workspace name without the prefix, for example "azure-l0-org-prd".
  workspaces = {
    for ws in local.config.workspaces :
    "${ws.area}-${ws.level}-${ws.component}-${ws.env}" => ws
  }

  # Invert "reads": for each workspace, the workspaces allowed to read its state.
  state_consumers = {
    for key, ws in local.workspaces :
    key => [for other_key, other in local.workspaces : other_key if contains(other.reads, key)]
  }

  variable_sets = local.config.variable_sets

  variable_set_attachments = merge([
    for set_key, set in local.variable_sets : {
      for ws_key in set.workspaces : "${set_key}/${ws_key}" => { set = set_key, workspace = ws_key }
    }
  ]...)

  # Inputs the YAML can name: the tenant-specific values plus the organisation, which level 4's remote
  # runs need for tfe_outputs and do not get from the GitHub workflow.
  variable_set_inputs = merge(var.variable_set_inputs, { hcp_organization = var.organization })

  variable_set_variables = merge([
    for set_key, set in local.variable_sets : {
      for var_key, v in set.variables : "${set_key}/${var_key}" => merge(v, { set = set_key, key = var_key })
    }
  ]...)

  workspace_name_pattern = "^[a-z]{2,5}-(azure|entra|tfc)-l[0-4]-[a-z]+-(prd|np)$"
}

resource "tfe_project" "this" {
  for_each = local.config.projects

  name        = "${var.prefix}-${each.key}"
  description = each.value.description
}

resource "tfe_workspace" "this" {
  for_each = local.workspaces

  name           = "${var.prefix}-${each.key}"
  project_id     = tfe_project.this[each.value.project].id
  description    = each.value.description
  queue_all_runs = false

  # Only remote runs use this; local runs use the version pinned in CI.
  terraform_version = each.value.execution_mode == "remote" ? var.terraform_version : null

  tags = {
    area  = each.value.area
    level = each.value.level
    env   = each.value.env
  }

  lifecycle {
    precondition {
      condition     = can(regex(local.workspace_name_pattern, "${var.prefix}-${each.key}"))
      error_message = "Workspace ${var.prefix}-${each.key} does not match ${local.workspace_name_pattern} (docs/naming.md)."
    }

    precondition {
      condition     = alltrue([for r in each.value.reads : contains(keys(local.workspaces), r)])
      error_message = "Workspace ${each.key} reads a workspace that is not defined: ${join(", ", each.value.reads)}."
    }

    # Levels are numbered per area, so the ordering rule only applies within an area.
    precondition {
      condition = alltrue([
        for r in each.value.reads :
        try(local.workspaces[r].area != each.value.area || tonumber(trimprefix(local.workspaces[r].level, "l")) <= tonumber(trimprefix(each.value.level, "l")), false)
      ])
      error_message = "Workspace ${each.key} reads a higher level. Upper levels may read lower levels, never the reverse."
    }
  }
}

resource "tfe_workspace_settings" "this" {
  for_each = local.workspaces

  workspace_id   = tfe_workspace.this[each.key].id
  execution_mode = each.value.execution_mode

  # Explicit allow-list instead of organisation-wide state access.
  global_remote_state       = false
  remote_state_consumer_ids = [for c in local.state_consumers[each.key] : tfe_workspace.this[c].id]
}

resource "tfe_variable_set" "this" {
  for_each = local.variable_sets

  name        = "${var.prefix}-${each.key}"
  description = each.value.description
}

resource "tfe_workspace_variable_set" "this" {
  for_each = local.variable_set_attachments

  variable_set_id = tfe_variable_set.this[each.value.set].id
  workspace_id    = tfe_workspace.this[each.value.workspace].id
}

resource "tfe_variable" "this" {
  for_each = local.variable_set_variables

  variable_set_id = tfe_variable_set.this[each.value.set].id
  key             = each.value.key
  category        = each.value.category
  # A variable either has a literal value or names an entry in local.variable_set_inputs.
  value       = try(each.value.value, local.variable_set_inputs[each.value.input])
  description = try(each.value.description, null)
  sensitive   = false
}
