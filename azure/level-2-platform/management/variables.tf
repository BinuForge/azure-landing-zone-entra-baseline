variable "prefix" {
  description = "Name prefix for every object (docs/naming.md)."
  type        = string
  default     = "lab"

  validation {
    condition     = can(regex("^[a-z]{2,5}$", var.prefix))
    error_message = "prefix must be 2-5 lowercase letters."
  }
}

variable "retention_in_days" {
  description = "How long operational logs are kept. 30 days is included in the ingestion price."
  type        = number
  default     = 30

  validation {
    condition     = var.retention_in_days >= 30 && var.retention_in_days <= 730
    error_message = "retention_in_days must be between 30 and 730."
  }
}

variable "daily_quota_gb" {
  description = "Hard cap on ingestion per day. Unlike a budget, it stops the spend: ingestion pauses until the next day."
  type        = number
  default     = 0.5

  validation {
    condition     = var.daily_quota_gb > 0 && var.daily_quota_gb <= 5
    error_message = "daily_quota_gb must be above 0 and at most 5 for the lab."
  }
}
