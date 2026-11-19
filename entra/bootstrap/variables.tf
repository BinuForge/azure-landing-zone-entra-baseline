variable "prefix" {
  description = "Name prefix for every object (docs/naming.md)."
  type        = string
  default     = "lab"

  validation {
    condition     = can(regex("^[a-z]{2,5}$", var.prefix))
    error_message = "prefix must be 2-5 lowercase letters."
  }
}

variable "github_oidc_subject_prefix" {
  description = "Start of the GitHub OIDC subject, using the repository's immutable IDs. Read it with: gh api repos/<owner>/<repo>/actions/oidc/customization/sub --jq .sub_claim_prefix"
  type        = string

  validation {
    condition     = can(regex("^repo:[A-Za-z0-9-]+@[0-9]+/[A-Za-z0-9._-]+@[0-9]+$", var.github_oidc_subject_prefix))
    error_message = "github_oidc_subject_prefix must use immutable IDs, for example repo:owner@123/repo@456."
  }
}

variable "github_owner" {
  description = "GitHub account that owns the repository."
  type        = string
  default     = "BinuForge"
}

variable "github_repository" {
  description = "Repository whose environments this root manages."
  type        = string
  default     = "azure-landing-zone-entra-baseline"
}

variable "github_apply_reviewer" {
  description = "GitHub user who must approve every apply (ADR-0006)."
  type        = string
  default     = "BinuForge"
}

variable "hcp_organization" {
  description = "HCP Terraform organisation, set as TF_CLOUD_ORGANIZATION in each environment."
  type        = string

  validation {
    condition     = can(regex("^[A-Za-z0-9_-]+$", var.hcp_organization))
    error_message = "hcp_organization must be an HCP Terraform organisation name."
  }
}
