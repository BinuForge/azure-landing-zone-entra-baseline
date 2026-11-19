locals {
  # Microsoft Graph's application ID is the same in every tenant.
  msgraph_app_id = "00000003-0000-0000-c000-000000000000"

  # The only Graph application permissions graph.yaml may name, by ID. IDs are the same in every tenant;
  # read one with:
  #   az rest --url "https://graph.microsoft.com/v1.0/servicePrincipals(appId='00000003-0000-0000-c000-000000000000')?\$select=appRoles" --query "appRoles[?value=='<name>'].id" -o tsv
  # Permissions that can assign directory roles, grant app permissions, add credentials or change every
  # group are left out on purpose, so granting one means changing this list as well as graph.yaml
  # (ADR-0016, decision 4). tests/graph.tftest.hcl checks that they stay out.
  graph_permission_ids = {
    "AdministrativeUnit.Read.All"                     = "134fd756-38ce-4afd-ba33-e9623dbe66c2"
    "Group.Create"                                    = "bf7b1a76-6e77-406b-b258-bf5c7720e98f"
    "Group.Read.All"                                  = "5b567255-7703-4780-807c-7be8301ae99b"
    "Policy.Read.All"                                 = "246dd0d5-5bd0-4def-940b-0421030a5b68"
    "Policy.ReadWrite.AuthenticationMethod"           = "29c18626-4985-4dcd-85c0-193eef327366"
    "Policy.ReadWrite.Authorization"                  = "fb221be6-99f2-473f-bd32-01c6a0e9ca3b"
    "Policy.ReadWrite.ConditionalAccess"              = "01c0a623-fc9b-48e9-b794-0756f8e8f067"
    "Policy.ReadWrite.ConsentRequest"                 = "999f8c63-0a38-4f1b-91fd-ed1947bdd1a9"
    "Policy.ReadWrite.CrossTenantAccess"              = "338163d7-f101-4c92-94ba-ca46fe52447c"
    "PrivilegedAssignmentSchedule.Read.AzureADGroup"  = "cd4161cb-f098-48f8-a884-1eda9a42434c"
    "PrivilegedEligibilitySchedule.Read.AzureADGroup" = "edb419d6-7edc-42a3-9345-509bfdf5d87c"
    "RoleAssignmentSchedule.Read.Directory"           = "d5fe8ce8-684c-4c83-a52c-46e882ce4be1"
    "RoleEligibilitySchedule.Read.Directory"          = "ff278e11-4a33-4d0c-83d2-d01dc58929a5"
    "RoleManagement.Read.Directory"                   = "483bed4a-2ad3-4361-a73b-c83ccdbdc53c"
    "RoleManagementPolicy.Read.AzureADGroup"          = "69e67828-780e-47fd-b28c-7b27d14864e6"
    "RoleManagementPolicy.Read.Directory"             = "fdc4c997-9942-4479-bfcb-75a36d1138df"
    "User.Read.All"                                   = "df021288-bdef-4463-88db-98f22de89214"
  }

  # One grant per identity and permission, keyed <identity>/<permission>.
  graph_grants = merge([
    for identity, permissions in yamldecode(file("${path.module}/graph.yaml")) : {
      for p in permissions : "${identity}/${p}" => { identity = identity, permission = p }
    }
  ]...)
}

data "azuread_service_principal" "msgraph" {
  client_id = local.msgraph_app_id
}

# Admin consent for each permission in graph.yaml. The maintainer's Global Administrator role grants it;
# no pipeline can grant a permission to itself or another app.
resource "azuread_app_role_assignment" "graph" {
  for_each = local.graph_grants

  app_role_id         = local.graph_permission_ids[each.value.permission]
  principal_object_id = module.identity[each.value.identity].object_id
  resource_object_id  = data.azuread_service_principal.msgraph.object_id
}
