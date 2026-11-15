variable "prefix" {
  description = "Name prefix for every object (docs/naming.md)."
  type        = string
  default     = "lab"

  validation {
    condition     = can(regex("^[a-z]{2,5}$", var.prefix))
    error_message = "prefix must be 2-5 lowercase letters."
  }
}

variable "hub_address_space" {
  description = "Hub VNet range (docs/architecture/address-plan.md)."
  type        = string
  default     = "10.10.0.0/22"

  validation {
    condition     = can(cidrhost(var.hub_address_space, 0)) && tonumber(split("/", var.hub_address_space)[1]) <= 22
    error_message = "hub_address_space must be a valid CIDR of /22 or larger, to leave room for every reserved subnet."
  }
}
