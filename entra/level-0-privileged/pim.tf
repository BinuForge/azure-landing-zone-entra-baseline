# PIM is applied by the maintainer with pim/Set-Pim.ps1, not by Terraform: the Azure CLI token cannot
# carry role management scopes, and no pipeline may hold them (ADR-0019). This file checks the result.
#
# The checks run in CI as lab-entra-l0-privileged-plan, which holds the PIM read permissions. A check
# warns, it does not fail, so a local plan still works when the maintainer's CLI token cannot read PIM.
locals {
  pim   = jsondecode(file("${path.module}/pim/pim.json"))
  roles = local.pim.roles

  pim_policy_query = {
    for name, r in local.roles : name => "scopeId eq '/' and scopeType eq 'DirectoryRole' and roleDefinitionId eq '${r.id}'"
  }
}

# The group whose members review admin consent requests. Created by Set-Pim.ps1, so looked up by name.
data "msgraph_resource" "cloudapp_admin_group" {
  url = "groups"
  query_parameters = {
    "$filter" = ["displayName eq '${var.prefix}-grp-role-cloudappadmin'"]
    "$select" = ["id,isAssignableToRole"]
  }
  response_export_values = {
    groups = "value"
  }
}

# Only break-glass accounts hold Global Administrator permanently. Everyone else is eligible and activates.
check "standing_global_administrator_is_break_glass_only" {
  data "msgraph_resource" "ga_schedules" {
    url = "roleManagement/directory/roleAssignmentSchedules"
    query_parameters = {
      "$filter" = ["roleDefinitionId eq '${local.global_administrator}'"]
    }
    response_export_values = {
      standing = "value[?assignmentType=='Assigned'].principalId"
    }
  }

  assert {
    condition     = try(toset(data.msgraph_resource.ga_schedules.output.standing) == toset(values(local.breakglass_ids)), false)
    error_message = "Someone other than the break-glass accounts holds standing Global Administrator. Remove it signed in as a break-glass account (docs/runbooks/entra-privileged.md)."
  }
}

check "every_pim_role_has_an_eligible_principal" {
  data "msgraph_resource" "eligibility" {
    url = "roleManagement/directory/roleEligibilitySchedules"
    response_export_values = {
      roles = "value[].roleDefinitionId"
    }
  }

  assert {
    condition     = try(alltrue([for r in values(local.roles) : contains(data.msgraph_resource.eligibility.output.roles, r.id)]), false)
    error_message = "A role in pim/pim.json has no eligible assignment. Run pim/Set-Pim.ps1."
  }
}

# One check per role: a check block holds one data source. tests/pim.tftest.hcl fails if pim.json lists a
# role without its check.
check "global_administrator_activation" {
  data "msgraph_resource" "ga_policy" {
    url = "policies/roleManagementPolicyAssignments"
    query_parameters = {
      "$filter" = [local.pim_policy_query["Global Administrator"]]
      "$expand" = ["policy($expand=rules)"]
    }
    response_export_values = {
      rules = "value[0].policy.rules"
    }
  }

  assert {
    condition = try(alltrue([for rule in data.msgraph_resource.ga_policy.output.rules :
      rule.id == "Expiration_EndUser_Assignment" ? rule.maximumDuration == local.roles["Global Administrator"].maximumActivation :
      rule.id == "Enablement_EndUser_Assignment" ? toset(rule.enabledRules) == toset(local.pim.activationRules) :
    true]), false)
    error_message = "Global Administrator's activation rules differ from pim/pim.json. Run pim/Set-Pim.ps1."
  }
}

check "privileged_role_administrator_activation" {
  data "msgraph_resource" "pra_policy" {
    url = "policies/roleManagementPolicyAssignments"
    query_parameters = {
      "$filter" = [local.pim_policy_query["Privileged Role Administrator"]]
      "$expand" = ["policy($expand=rules)"]
    }
    response_export_values = {
      rules = "value[0].policy.rules"
    }
  }

  assert {
    condition = try(alltrue([for rule in data.msgraph_resource.pra_policy.output.rules :
      rule.id == "Expiration_EndUser_Assignment" ? rule.maximumDuration == local.roles["Privileged Role Administrator"].maximumActivation :
      rule.id == "Enablement_EndUser_Assignment" ? toset(rule.enabledRules) == toset(local.pim.activationRules) :
    true]), false)
    error_message = "Privileged Role Administrator's activation rules differ from pim/pim.json. Run pim/Set-Pim.ps1."
  }
}

check "security_administrator_activation" {
  data "msgraph_resource" "secadmin_policy" {
    url = "policies/roleManagementPolicyAssignments"
    query_parameters = {
      "$filter" = [local.pim_policy_query["Security Administrator"]]
      "$expand" = ["policy($expand=rules)"]
    }
    response_export_values = {
      rules = "value[0].policy.rules"
    }
  }

  assert {
    condition = try(alltrue([for rule in data.msgraph_resource.secadmin_policy.output.rules :
      rule.id == "Expiration_EndUser_Assignment" ? rule.maximumDuration == local.roles["Security Administrator"].maximumActivation :
      rule.id == "Enablement_EndUser_Assignment" ? toset(rule.enabledRules) == toset(local.pim.activationRules) :
    true]), false)
    error_message = "Security Administrator's activation rules differ from pim/pim.json. Run pim/Set-Pim.ps1."
  }
}

check "cloud_application_administrator_activation" {
  data "msgraph_resource" "cloudapp_policy" {
    url = "policies/roleManagementPolicyAssignments"
    query_parameters = {
      "$filter" = [local.pim_policy_query["Cloud Application Administrator"]]
      "$expand" = ["policy($expand=rules)"]
    }
    response_export_values = {
      rules = "value[0].policy.rules"
    }
  }

  assert {
    condition = try(alltrue([for rule in data.msgraph_resource.cloudapp_policy.output.rules :
      rule.id == "Expiration_EndUser_Assignment" ? rule.maximumDuration == local.roles["Cloud Application Administrator"].maximumActivation :
      rule.id == "Enablement_EndUser_Assignment" ? toset(rule.enabledRules) == toset(local.pim.activationRules) :
    true]), false)
    error_message = "Cloud Application Administrator's activation rules differ from pim/pim.json. Run pim/Set-Pim.ps1."
  }
}
