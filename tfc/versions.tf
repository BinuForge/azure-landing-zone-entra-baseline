terraform {
  required_version = ">= 1.9"

  required_providers {
    tfe = {
      source  = "hashicorp/tfe"
      version = "~> 0.82"
    }
  }

  # Organisation comes from TF_CLOUD_ORGANIZATION so the code holds no tenant-specific values.
  cloud {
    workspaces {
      name = "lab-tfc-l0-core-prd"
    }
  }
}
