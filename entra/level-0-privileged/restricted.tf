# Tier 0 objects sit in a restricted management administrative unit. Only a role scoped to the unit can
# change them: Global Administrators, Groups Administrators, group owners and Graph application
# permissions are all blocked, and assigning a role on the unit is audited (ADR-0016, decision 5). The
# setting is fixed at creation.
resource "msgraph_resource" "emergency_au" {
  url = "directory/administrativeUnits"
  body = {
    displayName                  = "${var.prefix}-au-emergency"
    description                  = "Break-glass accounts and Conditional Access exclusion groups. Restricted management. Managed by ${var.prefix}-entra-l0-privileged-prd, ADR-0016."
    isMemberManagementRestricted = true
  }

  lifecycle {
    prevent_destroy = true
  }
}

# Every Conditional Access policy excludes this group (entra/level-1-ca). Its members are set when it is
# created, before it joins the unit: once inside, changing them needs a role scoped to the unit
# (docs/runbooks/entra-privileged.md). No owner is set, so the maintainer who creates it is the owner,
# and owners cannot manage members of a group in a restricted unit.
resource "azuread_group" "breakglass_exclusion" {
  display_name            = "${var.prefix}-grp-excl-breakglass"
  description             = "Break-glass accounts. Excluded from every Conditional Access policy. In ${var.prefix}-au-emergency, ADR-0016."
  security_enabled        = true
  mail_enabled            = false
  assignable_to_role      = false
  prevent_duplicate_names = true

  members = values(local.breakglass_ids)

  # Never with accounts that failed the checks.
  depends_on = [terraform_data.breakglass_checks]

  lifecycle {
    prevent_destroy = true
    # Unit membership is managed by msgraph_resource.emergency_au_member. Without this, azuread reads the
    # membership as drift and would take the group out of the restricted unit on the next apply.
    ignore_changes = [administrative_unit_ids]
  }
}

# Keys are names, known at plan time; the group's ID is known only after it is created.
locals {
  emergency_au_members = merge(local.breakglass_ids, {
    "${var.prefix}-grp-excl-breakglass" = azuread_group.breakglass_exclusion.object_id
  })
}

resource "msgraph_resource" "emergency_au_member" {
  for_each = toset(concat(local.breakglass_names, ["${var.prefix}-grp-excl-breakglass"]))

  url = "directory/administrativeUnits/${msgraph_resource.emergency_au.id}/members/$ref"
  body = {
    "@odata.id" = "https://graph.microsoft.com/v1.0/directoryObjects/${local.emergency_au_members[each.key]}"
  }

  depends_on = [terraform_data.breakglass_checks]
}
