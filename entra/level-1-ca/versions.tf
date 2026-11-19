terraform {
  required_version = ">= 1.9"

  required_providers {
    azuread = {
      source  = "hashicorp/azuread"
      version = "~> 3.10"
    }
    tfe = {
      source  = "hashicorp/tfe"
      version = "~> 0.83"
    }
  }

  # Local execution: plans and applies run on GitHub Actions with OIDC. Organisation comes from
  # TF_CLOUD_ORGANIZATION.
  cloud {
    workspaces {
      name = "lab-entra-l1-ca-prd"
    }
  }
}
