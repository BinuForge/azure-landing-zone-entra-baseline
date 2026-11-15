locals {
  subscription_scope = "/subscriptions/${var.subscription_id}"
  root_scope         = "/providers/Microsoft.Management/managementGroups/${data.azuread_client_config.current.tenant_id}"
  rg                 = { for k, rg in azurerm_resource_group.this : k => rg.id }

  # Built-in role IDs, checked with `az role definition list --name "<role>" --query [0].name`.
  role_ids = {
    reader                  = "acdd72a7-3385-48ef-bd42-f606fba81ae7"
    cost_management_reader  = "72fafb9e-0641-4937-9268-a91bfd8191a3"
    log_analytics_reader    = "73c42c96-874c-492b-b04d-ab87d138a893"
    cognitive_services_user = "5e0bd9bd-7b93-4f28-af87-19fc36ad61bd" # Cognitive Services OpenAI User: inference only, no listkeys
  }

  # A level may assign only these roles, and only to service principals (ADR-0012, decision 3).
  delegations = {
    l3 = [local.role_ids.cognitive_services_user, local.role_ids.log_analytics_reader]
    # Level 3's prompt-query alert reads the ops workspace with its own identity (threat model C-16).
    l3-management = [local.role_ids.log_analytics_reader]
    l4            = [local.role_ids.reader, local.role_ids.cost_management_reader, local.role_ids.log_analytics_reader]
  }

  delegation_conditions = {
    for level, roles in local.delegations : level => trimspace(<<-EOT
      (
       (
        !(ActionMatches{'Microsoft.Authorization/roleAssignments/write'})
       )
       OR
       (
        @Request[Microsoft.Authorization/roleAssignments:RoleDefinitionId] ForAnyOfAnyValues:GuidEquals {${join(", ", roles)}}
        AND
        @Request[Microsoft.Authorization/roleAssignments:PrincipalType] StringEqualsIgnoreCase 'ServicePrincipal'
       )
      )
      AND
      (
       (
        !(ActionMatches{'Microsoft.Authorization/roleAssignments/delete'})
       )
       OR
       (
        @Resource[Microsoft.Authorization/roleAssignments:RoleDefinitionId] ForAnyOfAnyValues:GuidEquals {${join(", ", roles)}}
       )
      )
    EOT
    )
  }

  # The table in ADR-0012, as data. Key: identity/role/scope.
  role_assignments = {
    "azure-l0-plan/reader/root"                       = { identity = "azure-l0-plan", role = "Reader", scope = local.root_scope }
    "azure-l0-apply/mg-contributor/root"              = { identity = "azure-l0-apply", role = "Management Group Contributor", scope = local.root_scope }
    "azure-l1-plan/reader/root"                       = { identity = "azure-l1-plan", role = "Reader", scope = local.root_scope }
    "azure-l1-apply/policy-contributor/root"          = { identity = "azure-l1-apply", role = "Resource Policy Contributor", scope = local.root_scope }
    "azure-l2-plan/reader/management"                 = { identity = "azure-l2-plan", role = "Reader", scope = local.rg.management }
    "azure-l2-plan/reader/connectivity"               = { identity = "azure-l2-plan", role = "Reader", scope = local.rg.connectivity }
    "azure-l2-plan/reader/dns"                        = { identity = "azure-l2-plan", role = "Reader", scope = local.rg.dns }
    "azure-l2-apply/contributor/management"           = { identity = "azure-l2-apply", role = "Contributor", scope = local.rg.management }
    "azure-l2-apply/network-contributor/connectivity" = { identity = "azure-l2-apply", role = "Network Contributor", scope = local.rg.connectivity }
    "azure-l2-apply/dns-contributor/dns"              = { identity = "azure-l2-apply", role = "Private DNS Zone Contributor", scope = local.rg.dns }
    "azure-l3-plan/reader/aiservices"                 = { identity = "azure-l3-plan", role = "Reader", scope = local.rg.aiservices }
    "azure-l3-plan/reader/connectivity"               = { identity = "azure-l3-plan", role = "Reader", scope = local.rg.connectivity }
    "azure-l3-plan/reader/dns"                        = { identity = "azure-l3-plan", role = "Reader", scope = local.rg.dns }
    "azure-l3-apply/contributor/aiservices"           = { identity = "azure-l3-apply", role = "Contributor", scope = local.rg.aiservices }
    "azure-l3-apply/spoke-join/connectivity"          = { identity = "azure-l3-apply", role = "custom:spoke-network-join", scope = local.rg.connectivity }
    "azure-l3-apply/spoke-join/dns"                   = { identity = "azure-l3-apply", role = "custom:spoke-network-join", scope = local.rg.dns }
    "azure-l3-apply/rbac-admin/aiservices"            = { identity = "azure-l3-apply", role = "Role Based Access Control Administrator", scope = local.rg.aiservices, condition = "l3" }
    "azure-l3-apply/rbac-admin/management"            = { identity = "azure-l3-apply", role = "Role Based Access Control Administrator", scope = local.rg.management, condition = "l3-management" }
    "azure-l4-plan/reader/subscription"               = { identity = "azure-l4-plan", role = "Reader", scope = local.subscription_scope }
    "azure-l4-apply/contributor/opsagent"             = { identity = "azure-l4-apply", role = "Contributor", scope = local.rg.opsagent }
    "azure-l4-apply/rbac-admin/subscription"          = { identity = "azure-l4-apply", role = "Role Based Access Control Administrator", scope = local.subscription_scope, condition = "l4" }
  }
}

# Lets the AI services spoke peer with the hub and use the hub's DNS zones without owning either.
resource "azurerm_role_definition" "spoke_network_join" {
  name        = "${var.prefix}-role-spoke-network-join"
  scope       = local.subscription_scope
  description = "Peer a spoke with the hub and link it to the hub's private DNS zones. Created by bootstrap, ADR-0012."

  permissions {
    actions = [
      "Microsoft.Network/virtualNetworks/read",
      "Microsoft.Network/virtualNetworks/peer/action",
      "Microsoft.Network/virtualNetworks/virtualNetworkPeerings/read",
      "Microsoft.Network/virtualNetworks/virtualNetworkPeerings/write",
      "Microsoft.Network/virtualNetworks/virtualNetworkPeerings/delete",
      "Microsoft.Network/privateDnsZones/read",
      "Microsoft.Network/privateDnsZones/join/action",
      "Microsoft.Network/privateDnsZones/virtualNetworkLinks/read",
      "Microsoft.Network/privateDnsZones/virtualNetworkLinks/write",
      "Microsoft.Network/privateDnsZones/virtualNetworkLinks/delete",
    ]
  }

  assignable_scopes = [local.rg.connectivity, local.rg.dns]
}

# Linking a diagnostic setting to a Log Analytics workspace needs sharedKeys/action on the workspace, a
# legacy authorisation check. The ops workspace has local authentication off, so the keys cannot send or
# query data. Scoped to the management group (the resource group), which survives teardowns; an
# assignment on the workspace itself would be deleted with it.
resource "azurerm_role_definition" "log_linker" {
  name        = "${var.prefix}-role-log-linker"
  scope       = local.subscription_scope
  description = "Send diagnostics to a Log Analytics workspace. Created by bootstrap, ADR-0012."

  permissions {
    actions = [
      "Microsoft.OperationalInsights/workspaces/read",
      "Microsoft.OperationalInsights/workspaces/sharedKeys/action",
    ]
  }

  assignable_scopes = [local.rg.management]
}

resource "azurerm_role_assignment" "log_linker" {
  for_each = toset(["azure-l3-apply"])

  scope              = local.rg.management
  principal_id       = azuread_service_principal.pipeline[each.key].object_id
  principal_type     = "ServicePrincipal"
  role_definition_id = azurerm_role_definition.log_linker.role_definition_resource_id
  description        = "Bootstrap, ADR-0012. Diagnostic settings to the ops workspace."
}

resource "azurerm_role_assignment" "pipeline" {
  for_each = local.role_assignments

  scope                = each.value.scope
  principal_id         = azuread_service_principal.pipeline[each.value.identity].object_id
  principal_type       = "ServicePrincipal"
  role_definition_name = startswith(each.value.role, "custom:") ? null : each.value.role
  role_definition_id   = each.value.role == "custom:spoke-network-join" ? azurerm_role_definition.spoke_network_join.role_definition_resource_id : null

  condition         = try(local.delegation_conditions[each.value.condition], null)
  condition_version = can(each.value.condition) ? "2.0" : null

  description = "Bootstrap, ADR-0012."
}
