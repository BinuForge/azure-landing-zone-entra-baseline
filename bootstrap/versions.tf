terraform {
  required_version = ">= 1.9"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.81"
    }
    azuread = {
      source  = "hashicorp/azuread"
      version = "~> 3.10"
    }
    github = {
      source  = "integrations/github"
      version = "~> 6.13"
    }
    azapi = {
      source  = "Azure/azapi"
      version = "~> 2.13"
    }
  }

  # State only. The workspace uses local execution, so plans run on the maintainer's machine with
  # their own `az login` (docs/runbooks/bootstrap.md). Organisation comes from TF_CLOUD_ORGANIZATION.
  cloud {
    workspaces {
      name = "lab-tfc-l0-bootstrap-prd"
    }
  }
}
