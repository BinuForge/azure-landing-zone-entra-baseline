# Signs in with GitHub OIDC: ARM_USE_OIDC, ARM_CLIENT_ID and ARM_TENANT_ID come from the workflow
# environment. The identity holds Group.Create, Group.Read.All and User.Read.All only (ADR-0016).
provider "azuread" {}
