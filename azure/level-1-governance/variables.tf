variable "prefix" {
  description = "Name prefix for every object (docs/naming.md)."
  type        = string
  default     = "lab"

  validation {
    condition     = can(regex("^[a-z]{2,5}$", var.prefix))
    error_message = "prefix must be 2-5 lowercase letters."
  }
}

variable "allowed_locations" {
  description = "Regions resources and resource groups may be created in. Primary and paired DR region (docs/naming.md)."
  type        = list(string)
  default     = ["australiaeast", "australiasoutheast"]
}

variable "approved_model_asset_ids" {
  description = "Foundry model asset IDs that may be deployed. Matched with `contains`, so a partial ID approves every version of that model."
  type        = list(string)
  default = [
    "azureml://registries/azure-openai/models/gpt-4.1-mini/",
    "azureml://registries/azure-openai/models/gpt-5-mini/",
  ]

  validation {
    condition     = length(var.approved_model_asset_ids) > 0 && alltrue([for id in var.approved_model_asset_ids : startswith(id, "azureml://registries/")])
    error_message = "List at least one model, as an azureml://registries/... asset ID."
  }
}

variable "apim_public_ip_exemption_expires_on" {
  description = "When the AI gateway's public IP exemption must be reviewed, RFC 3339. At most 90 days ahead; renewing it is a pull request."
  type        = string
  default     = "2027-02-13T00:00:00Z"

  validation {
    condition     = can(timecmp(var.apim_public_ip_exemption_expires_on, "2026-01-01T00:00:00Z"))
    error_message = "apim_public_ip_exemption_expires_on must be an RFC 3339 timestamp."
  }
}

variable "study_exemption_expires_on" {
  description = "When the study group's policy waiver ends, RFC 3339. At most 30 days ahead; renewing it is a pull request."
  type        = string
  default     = "2026-12-15T00:00:00Z"

  validation {
    condition     = can(timecmp(var.study_exemption_expires_on, "2026-01-01T00:00:00Z"))
    error_message = "study_exemption_expires_on must be an RFC 3339 timestamp, for example 2026-12-15T00:00:00Z."
  }
}
