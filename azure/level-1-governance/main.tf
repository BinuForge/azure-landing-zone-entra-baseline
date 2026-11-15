# Level 0 groups, looked up by name so a missing group fails the plan instead of a policy landing nowhere.
data "azurerm_management_group" "this" {
  for_each = toset(["root", "landingzones", "corp"])

  name = "${var.prefix}-mg-${each.key}"
}

data "azurerm_resource_group" "study" {
  name = "${var.prefix}-rg-study-np-ae"
}

data "azurerm_resource_group" "aiservices" {
  name = "${var.prefix}-rg-aiservices-prd-ae"
}

locals {
  mg = { for k, mg in data.azurerm_management_group.this : k => mg.id }

  # Built-in definition IDs, checked with `az policy definition show -n <id>` on 2026-11-15.
  builtin = {
    ai_restrict_network     = "037eea7a-bd0a-46c5-9a66-03aea78705d3"
    ai_disable_local_auth   = "71ef260a-8f18-47b7-abcb-62d0673d94dc" # gitleaks:allow public built-in policy ID, same in every tenant
    ai_approved_models      = "aafe3651-cb78-4f68-9f81-e7e41509110f"
    ai_model_eligibility    = "8791d062-ba96-4c34-b604-8538f7e30ca0"
    ai_diagnostic_logs      = "1b4d1c4e-934c-4703-944c-27c82c06bebb"
    ai_private_link         = "d6759c02-b87f-42b7-892e-71b3f471d782"
    ai_prompt_filtering     = "f3a9c2e0-7b4d-4d8f-9c3a-2e1f6b9a8d4e"
    ai_completion_filtering = "af253d37-136a-42f8-a1fc-30010c083d41"
    allowed_locations       = "e56962a6-4747-49cd-b67b-bf8b01975c4c"
    allowed_rg_locations    = "e765b5de-1225-4ba3-bd56-1ac6695af988"
    not_allowed_types       = "6c112d4e-5bc7-47ae-a041-ea2d9dccd749"
    mcsb                    = "1f3afdf9-d0c9-4c3d-847f-89da613e70a8"
  }

  # Prompt Shields filters audited on every deployment (threat model C-02), and protected material on output.
  prompt_filters     = ["Jailbreak", "Indirect Attack"]
  completion_filters = ["Protected Material Text", "Protected Material Code"]
}

# Microsoft's "Allowed Cognitive Services Kinds" built-in can only be assigned by Microsoft as a system
# assignment, so this custom definition does the same job.
resource "azurerm_policy_definition" "ai_allowed_kinds" {
  name                = "${var.prefix}-pol-ai-allowed-kinds-v1"
  display_name        = "AI services accounts should be an allowed kind"
  policy_type         = "Custom"
  mode                = "Indexed"
  management_group_id = local.mg.root

  parameters = jsonencode({
    allowedKinds = { type = "Array", metadata = { displayName = "Allowed kinds" } }
    effect       = { type = "String", allowedValues = ["Audit", "Deny", "Disabled"], defaultValue = "Deny" }
  })

  policy_rule = file("${path.module}/policies/ai-allowed-kinds.json")
}

# The tag policy Microsoft ships only denies, which would block the network watcher group Azure creates
# itself. This audits instead.
resource "azurerm_policy_definition" "rg_tag_audit" {
  name                = "${var.prefix}-pol-rg-tag-audit-v1"
  display_name        = "Resource groups should have a managed-by tag"
  policy_type         = "Custom"
  mode                = "All"
  management_group_id = local.mg.root

  parameters = jsonencode({
    tagName = { type = "String", metadata = { displayName = "Tag name" } }
  })

  policy_rule = file("${path.module}/policies/rg-tag-audit.json")
}
