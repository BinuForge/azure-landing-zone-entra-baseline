locals {
  # Microsoft's Zero Trust personas (docs/naming.md). Membership follows a rule, so no person is named in
  # code and nobody is added by hand. Admins are not a group: Conditional Access targets administrators by
  # directory role, which also covers roles activated through PIM. Workload identities need Workload ID
  # Premium for Conditional Access, which the lab does not have.
  personas = {
    internals = {
      description = "Every member account, including break-glass. Conditional Access excludes break-glass separately."
      rule        = "(user.userType -eq \"Member\")"
    }
    guests = {
      description = "Every guest account."
      rule        = "(user.userType -eq \"Guest\")"
    }
  }
}

# Dynamic membership needs Entra ID P1 or P2 for the members it covers.
resource "azuread_group" "persona" {
  for_each = local.personas

  display_name            = "${var.prefix}-grp-persona-${each.key}"
  description             = "${each.value.description} Managed by ${var.prefix}-entra-l0-org-prd, ADR-0016."
  security_enabled        = true
  mail_enabled            = false
  prevent_duplicate_names = true

  # Role-assignable groups are Tier 0 and live in level-0-privileged. Creating one needs a permission
  # this identity does not hold.
  assignable_to_role = false

  types = ["DynamicMembership"]
  dynamic_membership {
    enabled = true
    rule    = each.value.rule
  }

  # The apply identity, and only it: Group.Create lets it manage only the groups it owns.
  owners = [var.apply_object_id]
}
