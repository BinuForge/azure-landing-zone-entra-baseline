terraform {
  required_version = ">= 1.9"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.81"
    }
  }

  # Local execution: plans and applies run on GitHub Actions with OIDC. Organisation comes from
  # TF_CLOUD_ORGANIZATION.
  cloud {
    workspaces {
      name = "lab-azure-l2-connectivity-prd"
    }
  }
}
