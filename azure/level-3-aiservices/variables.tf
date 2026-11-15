variable "prefix" {
  description = "Name prefix for every object (docs/naming.md)."
  type        = string
  default     = "lab"

  validation {
    condition     = can(regex("^[a-z]{2,5}$", var.prefix))
    error_message = "prefix must be 2-5 lowercase letters."
  }
}

variable "spoke_address_space" {
  description = "AI services spoke range (docs/architecture/address-plan.md)."
  type        = string
  default     = "10.20.0.0/24"

  validation {
    condition     = can(cidrhost(var.spoke_address_space, 0))
    error_message = "spoke_address_space must be a valid CIDR."
  }
}

variable "model_deployments" {
  description = "Models to deploy. Each must also be approved by the level 1 policy, or the deployment is denied. Capacity is in thousands of tokens per minute."
  type = map(object({
    model_name    = string
    model_version = string
    capacity      = number
  }))
  default = {
    "gpt-5-mini" = { model_name = "gpt-5-mini", model_version = "2025-08-07", capacity = 10 }
  }

  validation {
    condition     = alltrue([for d in values(var.model_deployments) : d.capacity >= 1 && d.capacity <= 50])
    error_message = "Keep each deployment between 1 and 50 thousand tokens per minute in the lab (threat model C-18)."
  }
}

variable "enable_apim" {
  description = "Deploy the APIM AI gateway. Costs about USD 1.80 a day while on and takes 30-60 minutes to deploy (docs/cost.md). Turning it on or off is a pull request."
  type        = bool
  default     = true
}

variable "apim_publisher_email" {
  description = "Publisher contact APIM requires. No mailbox needs to exist behind it."
  type        = string
  default     = "noreply@binuforge.com"
}

variable "gateway_tokens_per_minute" {
  description = "Token limit per caller at the gateway (threat model C-18). One ops agent turn with tool results is about 5,000 tokens; 8,000 leaves headroom under the deployment's capacity."
  type        = number
  default     = 8000

  validation {
    condition     = var.gateway_tokens_per_minute >= 100 && var.gateway_tokens_per_minute <= 10000
    error_message = "gateway_tokens_per_minute must be between 100 and 10000 for the lab."
  }
}

variable "enable_prompt_logging" {
  description = "Send full request and response content to the prompt workspace. Off by default: turn on only for a test or an investigation (ADR-0010)."
  type        = bool
  default     = false
}

variable "prompt_workspace_daily_quota_gb" {
  description = "Hard daily cap on prompt content ingestion."
  type        = number
  default     = 0.1

  validation {
    condition     = var.prompt_workspace_daily_quota_gb > 0 && var.prompt_workspace_daily_quota_gb <= 1
    error_message = "prompt_workspace_daily_quota_gb must be above 0 and at most 1."
  }
}
