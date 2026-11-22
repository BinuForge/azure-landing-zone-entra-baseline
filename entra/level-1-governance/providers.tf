# Signs in with GitHub OIDC: ARM_USE_OIDC, ARM_CLIENT_ID and ARM_TENANT_ID come from the workflow
# environment. The apply identity holds Policy.Read.All and the ReadWrite permissions for authorisation,
# authentication methods, cross-tenant access and consent requests; the plan identity Policy.Read.All
# (ADR-0016). Tenant settings have no azuread resources, so they are set through Microsoft Graph.
provider "msgraph" {}
