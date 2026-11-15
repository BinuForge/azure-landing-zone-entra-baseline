variable "prefix" {
  description = "Name prefix for every object (docs/naming.md)."
  type        = string
  default     = "lab"

  validation {
    condition     = can(regex("^[a-z]{2,5}$", var.prefix))
    error_message = "prefix must be 2-5 lowercase letters."
  }
}
