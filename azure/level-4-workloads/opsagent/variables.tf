variable "prefix" {
  description = "Name prefix for every object (docs/naming.md)."
  type        = string
  default     = "lab"

  validation {
    condition     = can(regex("^[a-z]{2,5}$", var.prefix))
    error_message = "prefix must be 2-5 lowercase letters."
  }
}

variable "runner_object_id" {
  description = "Object ID of lab-azure-l4-opsagent-run, from the azure-opsagent-inputs variable set (bootstrap output)."
  type        = string

  validation {
    condition     = can(regex("^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$", var.runner_object_id))
    error_message = "runner_object_id must be a lowercase GUID."
  }
}
