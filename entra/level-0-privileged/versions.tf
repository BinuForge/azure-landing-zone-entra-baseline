terraform {
  required_version = ">= 1.9"

  required_providers {
    azuread = {
      source  = "hashicorp/azuread"
      version = "~> 3.10"
    }
    # Exact pin: a young provider whose schema still changes between minor versions (ADR-0001).
    msgraph = {
      source  = "microsoft/msgraph"
      version = "0.6.0"
    }
  }

  # Local execution. CI plans this workspace with a read-only identity; only the maintainer applies it,
  # from their own machine (ADR-0016, decision 1). Organisation comes from TF_CLOUD_ORGANIZATION.
  cloud {
    workspaces {
      name = "lab-entra-l0-privileged-prd"
    }
  }
}
