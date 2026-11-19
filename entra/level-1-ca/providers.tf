# Signs in with GitHub OIDC: ARM_USE_OIDC, ARM_CLIENT_ID and ARM_TENANT_ID come from the workflow
# environment. The apply identity holds Policy.Read.All and Policy.ReadWrite.ConditionalAccess only, the
# plan identity Policy.Read.All (ADR-0016).
provider "azuread" {}

# Reads level 0's outputs only (ADR-0013). TFE_TOKEN and TFE_ORGANIZATION come from the workflow.
provider "tfe" {}
