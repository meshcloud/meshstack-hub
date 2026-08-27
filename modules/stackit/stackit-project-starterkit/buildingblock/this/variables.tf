variable "creator" {
  type = object({
    type        = string
    identifier  = string
    displayName = string
    username    = optional(string)
    email       = optional(string)
    euid        = optional(string)
  })
  nullable    = false
  description = "Creator of the starterkit, who is granted the Project Admin role on the created project."
}

variable "name" {
  type        = string
  nullable    = false
  description = "Base name for the created meshProject and, through PROJECT_IDENTIFIER, its STACKIT project."
}

variable "landing_zone" {
  type        = string
  nullable    = false
  description = "Key into `landing_zone_refs`, chosen by the application team from the definition's select."

  validation {
    condition     = contains(keys(var.landing_zone_refs), var.landing_zone)
    error_message = "landing_zone must be one of the keys of landing_zone_refs: ${join(", ", keys(var.landing_zone_refs))}."
  }
}

variable "workspace_identifier" {
  type        = string
  nullable    = false
  description = "Identifier of the meshStack workspace the created project belongs to."
}

# `kind` is required rather than optional on this variable and on `landing_zone_refs` so that neither
# type contains `optional()`. Both are genuinely required inputs, and giving them a default purely to
# satisfy a convention would hide a misconfiguration behind a value nobody chose.
variable "platform_ref" {
  type = object({
    uuid = string
    kind = string
  })
  nullable    = false
  description = "Reference to the meshPlatform the tenant is created on. Required because the meshTenant v4 API references platforms by ref."
}

# The full map is needed, not just the selected entry: a SINGLE_SELECT input delivers only the label the
# application team picked, and a label is not a meshLandingZone reference. This is what the label is
# resolved against.
variable "landing_zone_refs" {
  type = map(object({
    name = string
    kind = string
  }))
  nullable    = false
  description = "Landing zones the application team can choose from, keyed by the label shown in the select."
}

# Null wherever the definition did not offer the input, which is every deployment with no networked
# landing zone. `network_static` decides whether an order gets a network; this only shapes it.
variable "network" {
  type = object({
    prefix_length    = number
    ipv4_nameservers = list(string)
  })
  description = "Spoke network created inside the project, chosen by the application team. Null for no network."

  validation {
    condition     = var.network == null || var.network.prefix_length > 0
    error_message = "network.prefix_length must be a positive IPv4 prefix length."
  }
}

variable "network_static" {
  type = object({
    matching_landing_zones = set(string)
    bbd_version_ref        = object({ uuid = string })
  })
  nullable    = false
  description = "Landing zone labels that get a spoke network, and the STACKIT Network definition version that creates it. An empty `matching_landing_zones` means no order ever gets one."

  validation {
    condition     = length(var.network_static.matching_landing_zones) == 0 || var.network_static.bbd_version_ref != null
    error_message = "network_static.bbd_version_ref is required when matching_landing_zones is not empty."
  }

  validation {
    condition     = alltrue([for lz in var.network_static.matching_landing_zones : contains(keys(var.landing_zone_refs), lz)])
    error_message = "network_static.matching_landing_zones must only contain keys of landing_zone_refs: ${join(", ", keys(var.landing_zone_refs))}."
  }
}

variable "tags" {
  type = object({
    project               = map(list(string))
    project_owner_tag_key = string
  })
  nullable    = false
  description = "`project` tags are applied to the created meshProject; `project_owner_tag_key` names the tag that receives the creator's display name, empty to set none."
}

variable "add_random_name_suffix" {
  type        = bool
  nullable    = false
  description = "Append a five-character random suffix to `name`. The STACKIT project name is the meshProject identifier, so this suffix is what keeps two teams' projects of the same name apart."
}
