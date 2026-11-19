variable "prefix" {
  description = "Name prefix for every object (docs/naming.md)."
  type        = string
  default     = "lab"

  validation {
    condition     = can(regex("^[a-z]{2,5}$", var.prefix))
    error_message = "prefix must be 2-5 lowercase letters."
  }
}

# A group created with Group.Create can be changed only by its owners, so the apply identity must own it.
# The plan identity makes the saved plan, so the owner cannot come from whoever is signed in: both
# environments hold the apply identity's object ID as the APPLY_OBJECT_ID secret (entra/bootstrap).
variable "apply_object_id" {
  description = "Object ID of lab-entra-l0-org-apply, which owns every group this level creates. From TF_VAR_apply_object_id."
  type        = string

  validation {
    condition     = can(regex("^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$", var.apply_object_id))
    error_message = "apply_object_id must be a GUID. In CI it comes from the environment's APPLY_OBJECT_ID secret."
  }
}
