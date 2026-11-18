locals {
  subscription_scope = "/subscriptions/${var.subscription_id}"
  root_scope         = "/providers/Microsoft.Management/managementGroups/${data.azuread_client_config.current.tenant_id}"
  rg                 = { for k, rg in azurerm_resource_group.this : k => rg.id }

  # Read actions that return log data rather than configuration. Reader, Role Based Access Control
  # Administrator and Resource Policy Contributor all include */read, and workspaces/query/read is a
  # management-plane read, so each of them can query Log Analytics. Their custom twins below remove these.
  log_reads = [
    "Microsoft.OperationalInsights/workspaces/query/*",
    "Microsoft.OperationalInsights/workspaces/tables/query/read",
    "Microsoft.OperationalInsights/workspaces/search/read",
    "Microsoft.Insights/logs/*",
    "Microsoft.Insights/components/query/read",
  ]

  # Custom roles rbac.yaml may name, by ID. Assigning by name made a fresh role fail with "could not find
  # role" until Azure listed it, minutes later.
  custom_roles = {
    config-reader      = azurerm_role_definition.config_reader.role_definition_id
    role-assigner      = azurerm_role_definition.role_assigner.role_definition_id
    policy-writer      = azurerm_role_definition.policy_writer.role_definition_id
    spoke-network-join = azurerm_role_definition.spoke_network_join.role_definition_id
    log-linker         = azurerm_role_definition.log_linker.role_definition_id
    soft-delete-purger = azurerm_role_definition.soft_delete_purger.role_definition_id
    report-writer      = azurerm_role_definition.report_writer.role_definition_id
  }

  scopes = merge(local.rg, {
    root         = local.root_scope
    subscription = local.subscription_scope
    reports      = azurerm_storage_container.reports.id
  })

  # Built-in role IDs, checked with `az role definition list --name "<role>" --query [0].name`.
  role_ids = {
    cost_management_reader  = "72fafb9e-0641-4937-9268-a91bfd8191a3"
    log_analytics_reader    = "73c42c96-874c-492b-b04d-ab87d138a893"
    cognitive_services_user = "5e0bd9bd-7b93-4f28-af87-19fc36ad61bd" # Cognitive Services OpenAI User: inference only, no listkeys
  }

  # A level may assign only these roles, and only to service principals (ADR-0012, decision 3). Log
  # Analytics Reader and the log reader are allowed on the management group only, so no level can grant
  # read on the prompt workspace (ADR-0010).
  delegations = {
    l3 = [local.role_ids.cognitive_services_user]
    # Level 3's prompt-query alert reads the ops workspace with its own identity (threat model C-16). That
    # identity belongs to the alert rule, so nothing can steer it into opening support requests.
    l3-management = [local.role_ids.log_analytics_reader]
    l4            = [azurerm_role_definition.config_reader.role_definition_id, azurerm_role_definition.cost_reader.role_definition_id]
    # The runner reads the ops workspace (threat model C-06).
    l4-management = [azurerm_role_definition.log_reader.role_definition_id]
  }

  # Roles a level may remove but no longer grant, so it can retire its own earlier grants after a change
  # like ADR-0012 decision 7. Empty once each level has applied the change.
  retiring = {}

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
        @Resource[Microsoft.Authorization/roleAssignments:RoleDefinitionId] ForAnyOfAnyValues:GuidEquals {${join(", ", concat(roles, lookup(local.retiring, level, [])))}}
       )
      )
    EOT
    )
  }

  # The table in ADR-0012, as data (rbac.yaml). Each entry gets one shape, so it can drive for_each.
  role_assignments = {
    for key, a in yamldecode(file("${path.module}/rbac.yaml")).assignments : key => {
      identity    = split("/", key)[0]
      scope       = lookup(local.scopes, try(split("/", key)[2], ""), null)
      role        = a.role
      custom      = startswith(a.role, "custom:") ? lookup(local.custom_roles, trimprefix(a.role, "custom:"), null) : null
      condition   = try(a.condition, null)
      description = try(a.description, "Bootstrap, ADR-0012.")
    }
  }
}

# The runner's cost and log readers. Cost Management Reader and Log Analytics Reader both include
# Microsoft.Support/*, which opens and changes support requests: a write. A read-only identity that
# processes data an attacker can influence holds the same reads without it (threat model T-02).
resource "azurerm_role_definition" "cost_reader" {
  name        = "${var.prefix}-role-cost-reader"
  scope       = local.root_scope
  description = "Cost Management Reader without support requests. Created by bootstrap, ADR-0012."

  permissions {
    actions = [
      "Microsoft.Consumption/*/read",
      "Microsoft.CostManagement/*/read",
      "Microsoft.Billing/billingPeriods/read",
      "Microsoft.Billing/billingProperty/read",
      "Microsoft.Resources/subscriptions/read",
      "Microsoft.Resources/subscriptions/resourceGroups/read",
      "Microsoft.Advisor/configurations/read",
      "Microsoft.Advisor/recommendations/read",
      "Microsoft.Management/managementGroups/read",
    ]
  }

  assignable_scopes = [local.root_scope]
}

resource "azurerm_role_definition" "log_reader" {
  name        = "${var.prefix}-role-log-reader"
  scope       = local.root_scope
  description = "Log Analytics Reader without support requests. Created by bootstrap, ADR-0012."

  permissions {
    actions = [
      "*/read",
      "Microsoft.OperationalInsights/workspaces/analytics/query/action",
      "Microsoft.OperationalInsights/workspaces/search/action",
    ]
    not_actions = ["Microsoft.OperationalInsights/workspaces/sharedKeys/read"]
  }

  assignable_scopes = [local.root_scope]
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

# Purging a soft-deleted APIM or AI account is a subscription-level action, outside level 3's resource
# group. Without it a teardown leaves both names reserved and blocks the next deploy. This role holds those
# actions and nothing else (docs/runbooks/destroy.md).
resource "azurerm_role_definition" "soft_delete_purger" {
  name        = "${var.prefix}-role-soft-delete-purger"
  scope       = local.subscription_scope
  description = "Read and purge soft-deleted APIM services and AI accounts. Created by bootstrap, ADR-0012."

  permissions {
    actions = [
      "Microsoft.ApiManagement/locations/deletedservices/read",
      "Microsoft.ApiManagement/locations/deletedservices/delete",
      "Microsoft.CognitiveServices/locations/resourceGroups/deletedAccounts/read",
      "Microsoft.CognitiveServices/locations/resourceGroups/deletedAccounts/delete",
    ]
  }

  assignable_scopes = [local.subscription_scope]
}

# Plan identities read configuration, never data (ADR-0012, decision 6). Defined at the root management
# group so levels 0 and 1 can hold it there.
resource "azurerm_role_definition" "config_reader" {
  name        = "${var.prefix}-role-config-reader"
  scope       = local.root_scope
  description = "Reader without log data. Created by bootstrap, ADR-0012."

  permissions {
    actions     = ["*/read"]
    not_actions = local.log_reads
  }

  assignable_scopes = [local.root_scope]
}

# Role Based Access Control Administrator without log data or support tickets. Every assignment of it
# carries a delegation condition naming the only roles it may grant (ADR-0012, decision 3).
resource "azurerm_role_definition" "role_assigner" {
  name        = "${var.prefix}-role-role-assigner"
  scope       = local.root_scope
  description = "Assign roles, under a delegation condition, without reading log data. Created by bootstrap, ADR-0012."

  permissions {
    actions = [
      "*/read",
      "Microsoft.Authorization/roleAssignments/write",
      "Microsoft.Authorization/roleAssignments/delete",
    ]
    not_actions = local.log_reads
  }

  assignable_scopes = [local.root_scope]
}

# Resource Policy Contributor without log data, ARM deployments or support tickets: level 1 writes
# policy objects directly.
resource "azurerm_role_definition" "policy_writer" {
  name        = "${var.prefix}-role-policy-writer"
  scope       = local.root_scope
  description = "Write policy definitions, initiatives, assignments and exemptions without reading log data. Created by bootstrap, ADR-0012."

  permissions {
    actions = [
      "*/read",
      "Microsoft.Authorization/policyAssignments/*",
      "Microsoft.Authorization/policyDefinitions/*",
      "Microsoft.Authorization/policyExemptions/*",
      "Microsoft.Authorization/policySetDefinitions/*",
      "Microsoft.PolicyInsights/*",
    ]
    not_actions = local.log_reads
  }

  assignable_scopes = [local.root_scope]
}

resource "azurerm_role_assignment" "pipeline" {
  for_each = local.role_assignments

  scope          = each.value.scope
  principal_id   = azuread_service_principal.pipeline[each.value.identity].object_id
  principal_type = "ServicePrincipal"

  # Custom roles by ID, in the form Azure returns for this scope, so the ID in state matches and nothing is
  # replaced. Built-in roles by name.
  role_definition_id = each.value.custom == null ? null : (
    startswith(each.value.scope, "/subscriptions/")
    ? "${local.subscription_scope}/providers/Microsoft.Authorization/roleDefinitions/${each.value.custom}"
    : "/providers/Microsoft.Authorization/roleDefinitions/${each.value.custom}"
  )
  role_definition_name = each.value.custom == null ? each.value.role : null

  condition         = try(local.delegation_conditions[each.value.condition], null)
  condition_version = each.value.condition == null ? null : "2.0"

  description = each.value.description

  lifecycle {
    precondition {
      condition     = each.value.scope != null && (each.value.custom != null || !startswith(each.value.role, "custom:"))
      error_message = "rbac.yaml: ${each.key} needs a known scope (root, subscription, a resource group or reports) and a known role."
    }
    precondition {
      condition     = (each.value.role == "custom:role-assigner") == (each.value.condition != null)
      error_message = "rbac.yaml: ${each.key}: every role assigner needs a delegation condition, and nothing else takes one."
    }
  }
}

# Assignments that had their own resources before rbac.yaml.
moved {
  from = azurerm_role_assignment.log_linker["azure-l3-apply"]
  to   = azurerm_role_assignment.pipeline["azure-l3-apply/log-linker/management"]
}

moved {
  from = azurerm_role_assignment.soft_delete_purger["azure-l3-apply"]
  to   = azurerm_role_assignment.pipeline["azure-l3-apply/soft-delete-purger/subscription"]
}

moved {
  from = azurerm_role_assignment.report_writer
  to   = azurerm_role_assignment.pipeline["azure-l4-opsagent-run/report-writer/reports"]
}
