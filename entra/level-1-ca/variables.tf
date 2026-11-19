variable "prefix" {
  description = "Name prefix for every object (docs/naming.md)."
  type        = string
  default     = "lab"

  validation {
    condition     = can(regex("^[a-z]{2,5}$", var.prefix))
    error_message = "prefix must be 2-5 lowercase letters."
  }
}

variable "trusted_countries" {
  description = "ISO 3166-1 alpha-2 codes for lab-nl-trusted-countries. CA003 blocks sign-ins from everywhere else."
  type        = list(string)
  default     = ["AU"]

  validation {
    condition     = length(var.trusted_countries) > 0 && alltrue([for c in var.trusted_countries : can(regex("^[A-Z]{2}$", c))])
    error_message = "trusted_countries needs at least one two-letter upper-case country code."
  }
}
