variable "test_context" {
  type = object({
    workspace   = string
    run_id      = string
    hub_git_ref = string

    fixtures = optional(object({
      stackit = object({
        project_id     = string
        mesh_tenant_id = string
      })
    }))
  })
  nullable = false
}

variable "scenario" {
  type        = string
  default     = "released_on_old_runner"
  description = "`released_on_old_runner` releases the definition on the old runner. `moved` moves it to the new runner and lists the old one as trusted."

  validation {
    condition     = contains(["released_on_old_runner", "moved"], var.scenario)
    error_message = "scenario must be released_on_old_runner or moved."
  }
}

variable "old_runner" {
  type = object({
    owned_by_workspace = string
    display_name       = string
  })
  default = {
    owned_by_workspace = "admin-customer"
    display_name       = "meshcloud-hosted Runner (deprecated)"
  }
  description = "The runner the definition starts on. It must offer the Azure token."
}

variable "new_runner" {
  type = object({
    owned_by_workspace = string
    display_name       = string
  })
  default = {
    owned_by_workspace = "admin-customer"
    display_name       = "meshcloud-hosted Runner (meshStack identity)"
  }
  description = "The runner the definition moves to. It must offer the Azure token and have another issuer than the old runner."
}
