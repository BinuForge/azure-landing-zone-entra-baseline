# Token comes from `terraform login` locally or TF_TOKEN_app_terraform_io in CI.
provider "tfe" {
  organization = var.organization
}
