locals {
  # Level 0 creates these groups. Bootstrap refers to them by name, from the naming convention, so it
  # never reads a higher level's state.
  mg_scope = {
    root    = "/providers/Microsoft.Management/managementGroups/${var.prefix}-mg-root"
    corp    = "/providers/Microsoft.Management/managementGroups/${var.prefix}-mg-corp"
    sandbox = "/providers/Microsoft.Management/managementGroups/${var.prefix}-mg-sandbox"
  }

  # The maintainer's standing Azure access. Read by default; write only on the one group bootstrap needs.
  # At a bank these would be PIM-eligible assignments to a group (ADR-0012, risks accepted).
  maintainer_roles = {
    "mg-reader/root"      = { role = "Management Group Reader", scope = local.mg_scope.root }
    "mg-contributor/corp" = { role = "Management Group Contributor", scope = local.mg_scope.corp }
  }
}

resource "azurerm_role_assignment" "maintainer" {
  for_each = local.maintainer_roles

  scope                = each.value.scope
  principal_id         = data.azuread_client_config.current.object_id
  principal_type       = "User"
  role_definition_name = each.value.role
  description          = "Bootstrap maintainer access, ADR-0012."
}

# Moving a subscription needs Owner on it, so this lives in bootstrap, not level 0 (ADR-0012).
# If the first apply fails with AuthorizationFailed, the role above has not propagated yet: re-run.
resource "azurerm_management_group_subscription_association" "corp" {
  management_group_id = local.mg_scope.corp
  subscription_id     = local.subscription_scope

  depends_on = [azurerm_role_assignment.maintainer]
}

# Hierarchy settings need managementgroups/settings/write at the root, which no built-in role short of
# Owner grants. This role has exactly the two actions Microsoft documents, and nothing else.
resource "azurerm_role_definition" "hierarchy_settings" {
  name        = "${var.prefix}-role-hierarchy-settings"
  scope       = local.root_scope
  description = "Read and update management group hierarchy settings only. Created by bootstrap, ADR-0012."

  permissions {
    actions = [
      "Microsoft.Management/managementgroups/settings/read",
      "Microsoft.Management/managementgroups/settings/write",
    ]
  }

  assignable_scopes = [local.root_scope]
}

resource "azurerm_role_assignment" "maintainer_hierarchy_settings" {
  scope              = local.root_scope
  principal_id       = data.azuread_client_config.current.object_id
  principal_type     = "User"
  role_definition_id = azurerm_role_definition.hierarchy_settings.role_definition_resource_id
  description        = "Bootstrap maintainer access, ADR-0012."
}

# Two tenant defaults most tenants leave open:
# - a new subscription lands in sandbox, with sandbox policy, instead of the tenant root with none;
# - creating a management group needs write rights at the root, instead of being open to every user.
resource "azapi_resource" "hierarchy_settings" {
  type      = "Microsoft.Management/managementGroups/settings@2023-04-01"
  name      = "default"
  parent_id = local.root_scope

  body = {
    properties = {
      defaultManagementGroup               = local.mg_scope.sandbox
      requireAuthorizationForGroupCreation = true
    }
  }

  # Azure takes the group's full ID but stores, and returns, its short name, so every plan showed a change.
  # Ignoring it has a cost: an in-place update would send the stored short name, which Azure refuses. To
  # change either setting, apply with -replace=azapi_resource.hierarchy_settings, which sends the config.
  # The check below watches the stored value.
  lifecycle {
    ignore_changes = [body.properties.defaultManagementGroup]
  }

  depends_on = [azurerm_role_assignment.maintainer_hierarchy_settings]
}

# Reads the stored setting on every plan. A failed read or a changed value is a warning, never an error.
check "new_subscriptions_land_in_sandbox" {
  data "azapi_resource" "hierarchy_settings" {
    type                   = "Microsoft.Management/managementGroups/settings@2023-04-01"
    name                   = "default"
    parent_id              = local.root_scope
    response_export_values = ["properties.defaultManagementGroup"]
  }

  assert {
    condition     = try(element(reverse(split("/", data.azapi_resource.hierarchy_settings.output.properties.defaultManagementGroup)), 0), "") == "${var.prefix}-mg-sandbox"
    error_message = "New subscriptions no longer land in ${var.prefix}-mg-sandbox. Set it back with az account management-group hierarchy-settings update (docs/runbooks/bootstrap.md)."
  }
}
