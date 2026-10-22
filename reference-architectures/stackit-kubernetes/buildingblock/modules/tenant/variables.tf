variable "release_on_destroy" {
  type        = bool
  nullable    = false
  description = "Leave the tenant in place when it is destroyed, and only drop it from the state."
}

variable "prevent_destroy" {
  type        = bool
  nullable    = false
  description = "Fail any plan that would destroy the tenant. Has no effect with `release_on_destroy`, which never destroys it."
}

variable "wait_for_completion" {
  type     = bool
  nullable = false
}

variable "metadata" {
  type = object({
    owned_by_workspace = string
    owned_by_project   = string
  })
  nullable = false
}

variable "spec" {
  type = object({
    platform_ref     = object({ uuid = string, kind = string })
    landing_zone_ref = object({ name = string, kind = string })
  })
  nullable = false
}
