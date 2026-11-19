variable "name" {
  description = "Name of the app registration and of the GitHub environment that unlocks it, for example lab-entra-l1-ca-apply (docs/naming.md)."
  type        = string

  validation {
    condition     = can(regex("^[a-z]{2,5}-[a-z]+-l[0-4]-([a-z]+-)?(plan|apply|run)$", var.name))
    error_message = "name must follow docs/naming.md, for example lab-entra-l1-ca-apply."
  }
}

variable "description" {
  description = "Description of the app registration: what the identity is for and which ADR decided it."
  type        = string
}

variable "phase" {
  description = "plan (any branch, no reviewer), apply (main only, with a reviewer) or run (main only, no reviewer)."
  type        = string

  validation {
    condition     = contains(["plan", "apply", "run"], var.phase)
    error_message = "phase must be plan, apply or run."
  }
}

variable "owner_object_ids" {
  description = "Object IDs that own the app registration and service principal: the person who runs bootstrap."
  type        = list(string)
}

variable "github_oidc_subject_prefix" {
  description = "Start of the GitHub OIDC subject, using the repository's immutable IDs, for example repo:owner@123/repo@456."
  type        = string

  validation {
    condition     = can(regex("^repo:[A-Za-z0-9-]+@[0-9]+/[A-Za-z0-9._-]+@[0-9]+$", var.github_oidc_subject_prefix))
    error_message = "github_oidc_subject_prefix must use immutable IDs, for example repo:owner@123/repo@456."
  }
}

variable "github_repository" {
  description = "Repository that holds the environment."
  type        = string
}

variable "reviewer_id" {
  description = "GitHub user ID that must approve every run of an apply environment (ADR-0006)."
  type        = number
}

variable "tenant_id" {
  description = "Entra tenant ID, stored as an environment secret because Actions prints variable values in public logs."
  type        = string
}

variable "subscription_id" {
  description = "Azure subscription ID, stored as an environment secret. Null for identities that manage no Azure resources."
  type        = string
  default     = null
}

variable "tf_cloud_organization" {
  description = "HCP Terraform organisation, set as the environment's TF_CLOUD_ORGANIZATION variable."
  type        = string
}
