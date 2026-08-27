variable "workspace" {
  type        = string
  nullable    = false
  description = "Identifier of the meshStack workspace that will own the created platform, location, landing zones, and (when networking is enabled) the hub network-area instance."
}

variable "use_global_location" {
  type        = bool
  nullable    = false
  description = "Use the global location instead of creating a dedicated location for this platform."
}

variable "stackit_org" {
  type        = string
  nullable    = false
  description = "STACKIT organization UUID under which the landing-zone folder, foundation project and tenant projects are created."

  validation {
    condition     = can(regex("^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$", var.stackit_org))
    error_message = "stackit_org must be a valid UUID."
  }
}

variable "stackit_owner_email" {
  type        = string
  nullable    = false
  description = "Owner email assigned to the STACKIT resourcemanager folder and foundation project."
}

variable "stackit_service_account_key" {
  type        = string
  sensitive   = true
  nullable    = false
  description = "STACKIT service account key JSON with `resource-manager.admin` on the organization. Used to create the landing-zone folder and foundation project."
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
    landingzone           = map(list(string))
    building_block        = map(list(string))
    project               = map(list(string))
    project_owner_tag_key = string
  })
  nullable    = false
  description = <<-EOT
  Tags forwarded to the nested STACKIT integrations.
  `landingzone` tags are applied to the created landing zones.
  `building_block` tags are applied to the nested building block definitions.
  `project` tags are applied to the meshProjects the starterkit creates.
  `project_owner_tag_key` names the tag that receives the creator's display name.
  EOT
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

variable "network" {
  type = object({
    hub_network_area_name            = optional(string, "hub")
    hub_network_ranges               = optional(list(string), ["10.0.0.0/16"])
    hub_transfer_network             = optional(string, "10.1.255.0/24")
    hub_min_prefix_length            = optional(number, 24)
    hub_max_prefix_length            = optional(number, 28)
    hub_default_prefix_length        = optional(number, 28)
    hub_default_nameservers          = optional(list(string), [])
    tenant_network_min_prefix_length = optional(number, 24)
    tenant_network_max_prefix_length = optional(number, 28)
  })
  default     = null
  description = "Optional hub-and-spoke network topology. Leave unset (null) to deploy only the sandbox landing zone. When set, additionally provisions a shared hub network area with the given address plan (`hub_*` fields), registers the self-service spoke `STACKIT Network` building block (`tenant_network_*` prefix bounds), and adds a dedicated `networked` STACKIT Project building block definition and landing zone whose projects are placed in the hub network area."
}

variable "playground_mode" {
  type        = bool
  nullable    = false
  description = "Deploy a throwaway platform: the platform identifier gets a random suffix so it does not occupy a name for good, and the landing-zone folder and foundation project are left destroyable. Set to false for a platform that is actually used. A playground platform and the building block definitions it registers are not meant to be published to other workspaces."
}

variable "hub" {
  type = object({
    git_ref   = optional(string, "main")
    bbd_draft = optional(bool, true)
  })
  const   = true
  default = { git_ref = "main", bbd_draft = true }

  description = <<-EOT
  `git_ref`: meshstack-hub reference used to source the nested foundation, network-area, and network integration modules. `const` so it can be interpolated into the module source at init time.
  `bbd_draft`: Forwarded as-is to those nested integrations' own `hub.bbd_draft`, so their building block definition draft state tracks this building block's own release state.
  EOT
}
