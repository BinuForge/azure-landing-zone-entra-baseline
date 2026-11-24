# Runs with a mock provider: no HCP token, no network calls, nothing created.
mock_provider "tfe" {
  # tfe_variable validates the "varset-" ID format, so the mock must return one.
  mock_resource "tfe_variable_set" {
    defaults = {
      id = "varset-mock000000000000"
    }
  }
}

variables {
  organization = "example-org"
  variable_set_inputs = {
    l4_plan_client_id  = "00000000-0000-0000-0000-00000000000a"
    l4_apply_client_id = "00000000-0000-0000-0000-00000000000b"
    tenant_id          = "00000000-0000-0000-0000-00000000000c"
    subscription_id    = "00000000-0000-0000-0000-00000000000d"
    # Not a credential; the same placeholder style keeps the fixture readable.
    opsagent_runner_object_id = "00000000-0000-0000-0000-00000000000e"
  }
}

run "workspace_names_follow_convention" {
  assert {
    condition     = alltrue([for ws in tfe_workspace.this : can(regex("^lab-(azure|entra|tfc)-l[0-4]-[a-z]+-(prd|np)$", ws.name))])
    error_message = "A workspace name does not follow docs/naming.md."
  }
}

run "platform_levels_run_locally_and_workloads_remotely" {
  assert {
    condition = alltrue([
      for key, s in tfe_workspace_settings.this :
      s.execution_mode == (local.workspaces[key].level == "l4" ? "remote" : "local")
    ])
    error_message = "Levels 0-3 must use local execution and level 4 must use remote execution."
  }
}

run "state_is_shared_only_with_declared_readers" {
  assert {
    condition     = alltrue([for s in tfe_workspace_settings.this : s.global_remote_state == false])
    error_message = "No workspace may share state with the whole organisation."
  }

  assert {
    condition = contains(
      tfe_workspace_settings.this["azure-l0-org-prd"].remote_state_consumer_ids,
      tfe_workspace.this["azure-l1-governance-prd"].id
    )
    error_message = "azure-l1-governance-prd reads azure-l0-org-prd, so it must be a state consumer."
  }

  assert {
    condition     = length(tfe_workspace_settings.this["azure-l4-opsagent-np"].remote_state_consumer_ids) == 0
    error_message = "Nothing reads the workload workspace, so it must have no state consumers."
  }
}

run "remote_workspaces_pin_terraform_version" {
  assert {
    condition     = tfe_workspace.this["azure-l4-opsagent-np"].terraform_version == "1.17.0"
    error_message = "Remote workspaces must pin the same Terraform version as CI."
  }
}

run "reading_a_higher_level_is_rejected" {
  command = plan

  variables {
    config_file = "tests/fixtures/upward-read.yaml"
  }

  expect_failures = [tfe_workspace.this]
}

run "bad_workspace_name_is_rejected" {
  command = plan

  variables {
    config_file = "tests/fixtures/bad-name.yaml"
  }

  expect_failures = [tfe_workspace.this]
}

run "variable_sets_attach_and_resolve_inputs" {
  variables {
    config_file         = "tests/fixtures/variable-set.yaml"
    variable_set_inputs = { tenant_id = "00000000-0000-0000-0000-000000000000" }
  }

  assert {
    condition     = tfe_variable.this["workload-credentials/ARM_TENANT_ID"].value == "00000000-0000-0000-0000-000000000000"
    error_message = "Variable values named by input must come from variable_set_inputs."
  }

  assert {
    condition     = length(tfe_workspace_variable_set.this) == 1
    error_message = "The variable set must attach to exactly the workspaces listed."
  }
}

run "level_4_remote_runs_know_their_organisation" {
  command = plan

  assert {
    condition     = tfe_variable.this["azure-opsagent-inputs/TFE_ORGANIZATION"].value == "example-org"
    error_message = "Level 4 runs remotely and needs TFE_ORGANIZATION from its variable set for tfe_outputs."
  }

  assert {
    condition     = tfe_variable.this["azure-opsagent-inputs/TFE_ORGANIZATION"].category == "env"
    error_message = "TFE_ORGANIZATION must be an environment variable for the tfe provider to read it."
  }
}

run "level_4_gets_separate_plan_and_apply_identities" {
  command = plan

  assert {
    condition     = tfe_variable.this["azure-workload-credentials/TFC_AZURE_PLAN_CLIENT_ID"].value != tfe_variable.this["azure-workload-credentials/TFC_AZURE_APPLY_CLIENT_ID"].value
    error_message = "Level 4 plan and apply must use different identities."
  }

  # HCP falls back to TFC_AZURE_RUN_CLIENT_ID for a phase without its own ID, which would let one
  # identity run both phases.
  assert {
    condition     = !contains(keys(tfe_variable.this), "azure-workload-credentials/TFC_AZURE_RUN_CLIENT_ID")
    error_message = "Level 4 must not set a shared TFC_AZURE_RUN_CLIENT_ID."
  }

  assert {
    condition     = tfe_variable.this["azure-workload-credentials/TFC_AZURE_PROVIDER_AUTH"].value == "true"
    error_message = "Level 4 must use HCP dynamic credentials."
  }

  assert {
    condition     = alltrue([for k, _ in tfe_workspace_variable_set.this : strcontains(k, "/azure-l4-")])
    error_message = "Credential variable sets may attach only to level 4 workspaces."
  }
}

run "workspaces_are_safe_deleted_by_default" {
  assert {
    condition     = alltrue([for ws in tfe_workspace.this : ws.force_delete == false])
    error_message = "Workspaces must be safe-deleted unless a final teardown sets allow_force_delete."
  }
}
