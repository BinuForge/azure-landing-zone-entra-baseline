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
