variable "workspace" {
  type        = string
  description = "Identifier of the meshStack workspace that will own the created location, platform and landing zone."
}

variable "use_global_location" {
  type        = bool
  nullable    = false
  description = "Use the global location instead of creating a dedicated location for this platform."
}

variable "stackit_org" {
  type        = string
  description = "STACKIT organization UUID under which the landing-zone folder, backplane project and tenant projects are created."
  nullable    = false

  validation {
    condition     = can(regex("^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$", var.stackit_org))
    error_message = "stackit_org must be a valid UUID."
  }
}

variable "stackit_owner_email" {
  type        = string
  description = "Owner email assigned to the STACKIT resourcemanager folder and backplane project."
  nullable    = false
}

variable "stackit_service_account_key" {
  type        = string
  sensitive   = true
  nullable    = false
  description = "STACKIT service account key JSON with `resource-manager.admin` on the organization. Used to create the landing-zone folder and backplane project."
}

variable "platform_identifier" {
  type        = string
  nullable    = false
  description = "Identifier for the STACKIT sandbox platform created in meshStack (letters, digits and dashes only)."

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
  nullable    = false
  description = "Tags forwarded to the nested STACKIT Project integration. `landingzone` tags are applied to the default landing zone; `building_block` tags are applied to the nested building block definition."
}

variable "role_mapping" {
  type        = map(list(string))
  nullable    = false
  description = "Default mapping from meshStack roles to STACKIT project roles for the nested STACKIT Project integration. Values can be built-in STACKIT roles or custom STACKIT role names."
}

variable "stackit_organization_onboarding_enabled" {
  type        = bool
  nullable    = false
  description = "Whether the nested STACKIT Project integration adds meshStack project users to the STACKIT organization before applying project-level role assignments. Disable if organization membership is managed outside this landing zone."
}

variable "network_area_tag_name" {
  type        = string
  default     = null
  description = "Name of the meshStack landing zone tag whose value is used as the STACKIT project's `networkArea` label, forwarded to the nested STACKIT Project integration. Set to null (default) to skip network area assignment."
}

variable "hub" {
  type = object({
    git_ref   = optional(string, "main")
    bbd_draft = optional(bool, true)
  })
  const    = true
  nullable = false

  description = <<-EOT
  `git_ref`: meshstack-hub reference used to source the nested STACKIT project integration module. `const` so it can be interpolated into the module source at init time.
  `bbd_draft`: Forwarded as-is to the nested STACKIT project integration's own `hub.bbd_draft`, so its building block definition draft state tracks this building block's own release state.
  EOT
}

