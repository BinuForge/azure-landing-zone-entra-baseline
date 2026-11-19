# Runs with a mock provider: no sign-in, no network calls, nothing created.
mock_provider "azuread" {}

variables {
  apply_object_id = "00000000-0000-0000-0000-0000000000a1"
}

run "personas_follow_the_naming_convention" {
  command = plan

  assert {
    condition     = toset([for g in azuread_group.persona : g.display_name]) == toset(["lab-grp-persona-internals", "lab-grp-persona-guests"])
    error_message = "Persona groups are lab-grp-persona-<persona> (docs/naming.md)."
  }
}

run "membership_follows_a_rule_not_a_person" {
  command = plan

  assert {
    condition = (
      one(azuread_group.persona["internals"].dynamic_membership).rule == "(user.userType -eq \"Member\")" &&
      one(azuread_group.persona["guests"].dynamic_membership).rule == "(user.userType -eq \"Guest\")"
    )
    error_message = "Internals are members and guests are guests, by rule."
  }

  assert {
    condition     = alltrue([for g in azuread_group.persona : contains(g.types, "DynamicMembership") && one(g.dynamic_membership).enabled])
    error_message = "Every persona group has dynamic membership on, so nobody is added by hand."
  }
}

run "the_apply_identity_owns_every_group_and_nothing_else_does" {
  command = plan

  assert {
    condition     = alltrue([for g in azuread_group.persona : g.owners == toset(["00000000-0000-0000-0000-0000000000a1"])])
    error_message = "Group.Create manages only owned groups, so the apply identity must be the one owner."
  }
}

run "groups_are_security_only_and_not_role_assignable" {
  command = plan

  assert {
    condition     = alltrue([for g in azuread_group.persona : g.security_enabled && !g.mail_enabled && !g.assignable_to_role])
    error_message = "Persona groups are security groups. Role-assignable groups are Tier 0 and live in level-0-privileged."
  }
}

run "owner_must_be_a_guid" {
  command = plan

  variables {
    apply_object_id = ""
  }

  expect_failures = [var.apply_object_id]
}
