variable "workspace" {
  type        = string
  description = "Identifier of the meshStack workspace that will own the created platform, location, landing zones, and the hub network-area instance."
}

variable "use_global_location" {
  type        = bool
  default     = false
  description = "Use the global location instead of creating a dedicated location for this platform."
}

variable "stackit_org" {
  type        = string
  description = "STACKIT organization UUID under which the landing-zone folder, backplane project and tenant projects are created."

  validation {
    condition     = can(regex("^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$", var.stackit_org))
    error_message = "stackit_org must be a valid UUID."
  }
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
  type        = string
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

  default     = { landingzone = {}, building_block = {} }
  description = "Tags forwarded to the nested foundation, network-area, and network integrations. `landingzone` tags are applied to the created landing zones; `building_block` tags are applied to the nested building block definitions."
}

variable "role_mapping" {
  type        = map(list(string))
  description = "Default mapping from meshStack roles to STACKIT project roles for the nested STACKIT Project integration. Values can be built-in STACKIT roles or custom STACKIT role names."

  default = {
    admin  = ["owner"]
    user   = ["editor"]
    reader = ["reader"]
  }
}

variable "stackit_organization_onboarding_enabled" {
  type        = bool
  default     = true
  description = "Whether the nested STACKIT Project integration adds meshStack project users to the STACKIT organization before applying project-level role assignments. Disable if organization membership is managed outside this landing zone."
}

variable "network_area_tag_name" {
  type        = string
  default     = "StackitNetworkArea"
  description = "Name of the meshStack landing zone tag whose value is the hub network area's ID. Forwarded to the foundation's nested STACKIT Project integration (so it knows which tag to read) and set on the `networked` landing zone created here (with the hub's network area ID as its value)."
}

variable "hub_network_area_name" {
  type        = string
  default     = "hub"
  description = "Name of the hub STACKIT network area instance."
}

variable "hub_network_ranges" {
  type        = list(string)
  default     = ["10.0.0.0/16"]
  description = "List of IPv4 CIDR ranges available to projects within the hub network area."
}

variable "hub_transfer_network" {
  type        = string
  default     = "10.1.255.0/24"
  description = "IPv4 CIDR range used as the transfer network between the hub network area and connected networks. Must not overlap with `hub_network_ranges`."
}

variable "hub_min_prefix_length" {
  type        = number
  default     = 24
  description = "Minimum prefix length allowed for networks created within the hub network area."
}

variable "hub_max_prefix_length" {
  type        = number
  default     = 28
  description = "Maximum prefix length allowed for networks created within the hub network area."
}

variable "hub_default_prefix_length" {
  type        = number
  default     = 28
  description = "Default prefix length used for networks created within the hub network area when none is specified."
}

variable "hub_default_nameservers" {
  type        = list(string)
  default     = []
  description = "Default IPv4 nameservers assigned to networks created within the hub network area."
}

variable "tenant_network_min_prefix_length" {
  type        = number
  default     = 24
  description = "Minimum allowed IPv4 prefix length for the spoke network BBD's prefix length input, offered to application teams ordering spoke networks."
}

variable "tenant_network_max_prefix_length" {
  type        = number
  default     = 28
  description = "Maximum allowed IPv4 prefix length for the spoke network BBD's prefix length input, offered to application teams ordering spoke networks."
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
