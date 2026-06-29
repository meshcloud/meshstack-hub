variable "workspace" {
  type        = string
  description = "Identifier of the meshStack workspace that will own the created location, platform and landing zone."
}

variable "stackit_org" {
  type        = string
  description = "STACKIT organization ID under which the landing-zone folder and backplane project are created."
}

variable "stackit_owner_email" {
  type        = string
  description = "Owner email assigned to the STACKIT resourcemanager folder and backplane project."
}

variable "stackit_service_account_key" {
  type        = string
  sensitive   = true
  description = "STACKIT service account key JSON with `resource-manager.admin` on the organization. Used to create the landing-zone folder and backplane project."
}

variable "platform_identifier" {
  type = string
  validation {
    condition     = can(regex("^[a-zA-Z0-9-]+$", var.platform_identifier))
    error_message = "platform_identifier must only contain letters, digits, and dashes."
  }
}

variable "tags" {
  type = object({
    landingzone    = map(list(string))
    building_block = map(list(string))
  })

  default = { landingzone = {}, building_block = {} }
}

variable "git_ref" {
  type        = string
  default     = "main"
  const       = true
  description = "meshstack-hub reference used to source the nested STACKIT project integration module. `const` so it can be interpolated into the module source at init time."
}

