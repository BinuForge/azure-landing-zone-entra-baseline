locals {
  # The two emergency access accounts, created by hand (entra/break-glass). Found by name, so no object ID
  # is committed. Their protection is the restricted unit, the checks below and the sign-in alert, not a
  # hidden name.
  breakglass_names = ["${var.prefix}-emergency-01", "${var.prefix}-emergency-02"]

  # Every account whose alias starts with the prefix, so a third look-alike account fails the checks.
  breakglass = { for u in data.msgraph_resource.breakglass.output.users : u.mailNickname => u }
  breakglass_ids = {
    for n in local.breakglass_names : n => try(local.breakglass[n].id, null)
  }

  global_administrator = "62e90394-69f5-4237-9190-012177145e10" # role template ID, the same in every tenant
}

data "msgraph_resource" "breakglass" {
  url = "users"
  query_parameters = {
    "$filter" = ["startswith(mailNickname,'${var.prefix}-emergency-')"]
    "$select" = ["id,mailNickname,accountEnabled,onPremisesSyncEnabled,userType"]
  }
  response_export_values = {
    users = "value"
  }
}

data "msgraph_resource" "global_administrators" {
  url = "directoryRoles(roleTemplateId='${local.global_administrator}')/members"
  query_parameters = {
    "$select" = ["id"]
  }
  response_export_values = {
    ids = "value[].id"
  }
}

# The plan fails, in CI and on the maintainer's machine, if either account is missing, disabled, synced
# from on-premises, a guest, or no longer a Global Administrator (entra/break-glass/README.md).
resource "terraform_data" "breakglass_checks" {
  input = local.breakglass_ids

  lifecycle {
    precondition {
      condition     = toset(keys(local.breakglass)) == toset(local.breakglass_names)
      error_message = "Expected exactly ${join(" and ", local.breakglass_names)}. Found: ${join(", ", keys(local.breakglass))}."
    }
    precondition {
      condition     = alltrue([for u in values(local.breakglass) : u.accountEnabled == true])
      error_message = "A break-glass account is disabled."
    }
    precondition {
      condition     = alltrue([for u in values(local.breakglass) : try(u.onPremisesSyncEnabled, null) != true])
      error_message = "A break-glass account is synced from on-premises. It must be cloud-only."
    }
    precondition {
      condition     = alltrue([for u in values(local.breakglass) : u.userType == "Member"])
      error_message = "A break-glass account is not a member account."
    }
    precondition {
      condition     = alltrue([for id in values(local.breakglass_ids) : contains(data.msgraph_resource.global_administrators.output.ids, id)])
      error_message = "A break-glass account no longer holds Global Administrator as a permanent, active role."
    }
  }
}
