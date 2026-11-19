terraform {
  required_version = ">= 1.9"

  required_providers {
    azuread = {
      source  = "hashicorp/azuread"
      version = "~> 3.10"
    }
    github = {
      source  = "integrations/github"
      version = "~> 6.13"
    }
  }

  # State only. Local execution, so plans run on the maintainer's machine with their own `az login`
  # (docs/runbooks/bootstrap.md). Organisation comes from TF_CLOUD_ORGANIZATION.
  cloud {
    workspaces {
      name = "lab-entra-l0-bootstrap-prd"
    }
  }
}
