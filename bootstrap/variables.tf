variable "subscription_id" {
  description = "Lab subscription ID. Supplied from git-ignored env/*.auto.tfvars, never committed."
  type        = string

  validation {
    condition     = can(regex("^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$", var.subscription_id))
    error_message = "subscription_id must be a GUID."
  }
}

variable "prefix" {
  description = "Name prefix for every object (docs/naming.md)."
  type        = string
  default     = "lab"

  validation {
    condition     = can(regex("^[a-z]{2,5}$", var.prefix))
    error_message = "prefix must be 2-5 lowercase letters."
  }
}

variable "location" {
  description = "Azure region for the lab (docs/naming.md)."
  type        = string
  default     = "australiaeast"

  validation {
    condition     = contains(["australiaeast", "australiasoutheast", "southeastasia", "eastasia"], var.location)
    error_message = "location must be a region with a code in docs/naming.md."
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
  description = "Repository whose environments bootstrap manages."
  type        = string
  default     = "azure-landing-zone-entra-baseline"
}

variable "github_apply_reviewer" {
  description = "GitHub user who must approve every apply (ADR-0006)."
  type        = string
  default     = "BinuForge"
}

variable "hcp_organization" {
  description = "HCP Terraform organisation, used in the level 4 dynamic credential subjects."
  type        = string

  validation {
    condition     = can(regex("^[A-Za-z0-9_-]+$", var.hcp_organization))
    error_message = "hcp_organization must be an HCP Terraform organisation name."
  }
}

variable "budget_amount" {
  description = "Monthly budget in the billing currency. Alerts only: a budget never stops spend."
  type        = number
  default     = 30

  validation {
    condition     = var.budget_amount > 0
    error_message = "budget_amount must be greater than zero."
  }
}

variable "budget_start_date" {
  description = "First day of the first budget month, RFC 3339. Azure requires the first of a month."
  type        = string
  default     = "2026-11-01T00:00:00Z"

  validation {
    condition     = can(regex("^[0-9]{4}-[0-9]{2}-01T00:00:00Z$", var.budget_start_date))
    error_message = "budget_start_date must be the first of a month, for example 2026-11-01T00:00:00Z."
  }
}

variable "budget_contact_emails" {
  description = "Who receives budget alerts. Supplied from git-ignored env/*.auto.tfvars."
  type        = list(string)

  validation {
    condition     = length(var.budget_contact_emails) > 0 && alltrue([for e in var.budget_contact_emails : can(regex("^[^@\\s]+@[^@\\s]+\\.[^@\\s]+$", e))])
    error_message = "budget_contact_emails needs at least one valid email address."
  }
}
