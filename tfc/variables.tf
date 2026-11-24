variable "organization" {
  description = "HCP Terraform organisation name."
  type        = string
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

variable "config_file" {
  description = "YAML file, relative to this root, that defines projects, workspaces and variable sets."
  type        = string
  default     = "workspaces.yaml"
}

variable "terraform_version" {
  description = "Terraform version for remote-execution workspaces. Keep in step with CI."
  type        = string
  default     = "1.17.0"
}

variable "variable_set_inputs" {
  description = "Tenant-specific values referenced by name from variable sets in the YAML, so the YAML holds none."
  type        = map(string)
  default     = {}
}

variable "allow_force_delete" {
  description = "Let terraform destroy delete workspaces that still hold state. Set only for the final teardown of a lab, never while its resources are in use."
  type        = bool
  default     = false
}
