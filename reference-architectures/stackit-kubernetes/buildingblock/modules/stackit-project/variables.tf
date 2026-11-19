variable "release_on_destroy" {
  type        = bool
  nullable    = false
  description = "Leave the building block, and so the STACKIT project, in place on destroy."
}

variable "prevent_destroy" {
  type        = bool
  nullable    = false
  description = "Fail any plan that would destroy the building block."
}

variable "definition_version_ref" {
  type = object({
    uuid = string
  })
  nullable    = false
  description = "STACKIT Project definition version the building block is created from."
}

variable "display_name" {
  type     = string
  nullable = false
}

variable "target_ref" {
  type = object({
    kind = string
    uuid = string
  })
  nullable    = false
  description = "Tenant the STACKIT project is created for."
}
