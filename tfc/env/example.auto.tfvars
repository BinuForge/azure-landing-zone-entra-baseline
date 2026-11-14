# Copy to env/<tenant>.auto.tfvars (git-ignored) and pass with -var-file.
organization = "your-hcp-organisation"
prefix       = "lab"

# From `terraform output identity_client_ids` in bootstrap/, and `az account show`.
variable_set_inputs = {
  l4_plan_client_id  = "00000000-0000-0000-0000-000000000000"
  l4_apply_client_id = "00000000-0000-0000-0000-000000000000"
  tenant_id          = "00000000-0000-0000-0000-000000000000"
  subscription_id    = "00000000-0000-0000-0000-000000000000"
}
