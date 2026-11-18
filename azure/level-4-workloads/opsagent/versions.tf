terraform {
  required_version = ">= 1.9"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.81"
    }
    tfe = {
      source  = "hashicorp/tfe"
      version = "~> 0.83"
    }
  }

  # Remote execution: plans and applies run in HCP Terraform with dynamic credentials, so no Azure
  # credential reaches GitHub (ADR-0012). Organisation comes from TF_CLOUD_ORGANIZATION.
  cloud {
    workspaces {
      name = "lab-azure-l4-opsagent-np"
    }
  }
}
