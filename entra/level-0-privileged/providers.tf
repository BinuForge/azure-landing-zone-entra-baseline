# In CI: GitHub OIDC as lab-entra-l0-privileged-plan, which only reads (ARM_USE_OIDC, ARM_CLIENT_ID and
# ARM_TENANT_ID from the workflow). On the maintainer's machine: their `az login` as Global Administrator.
provider "azuread" {}

# The restricted administrative unit and its members, which azuread has no resource for.
provider "msgraph" {}
