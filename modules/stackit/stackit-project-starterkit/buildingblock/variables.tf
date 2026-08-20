variable "creator" {
  type = object({
    type        = string
    identifier  = string
    displayName = string
    username    = optional(string)
    email       = optional(string)
    euid        = optional(string)
  })
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

# Version refs of the `STACKIT Network` definition, keyed by the same labels as `landing_zone_refs`.
# Only landing zones attached to a network area have an entry, which is what decides whether a spoke
# network can be requested at all — the module never has to know what those labels are called.
variable "network_bbd_version_refs" {
  type = map(object({
    uuid = string
  }))
  default     = {}
  description = "Version refs of the STACKIT Network building block definition, keyed by landing zone label. A landing zone without an entry cannot have a spoke network."
}

# Whether a spoke network is created is decided by the landing zone, not by this object: it applies
# only where `network_bbd_version_refs` has an entry, and is ignored everywhere else. That is what lets
# it carry a usable default — a sandbox order does not have to blank it out to succeed.
variable "network" {
  type = object({
    prefix_length    = optional(number, 25)
    ipv4_nameservers = optional(list(string), [])
  })
  default     = {}
  description = "Spoke network created inside the project, in landing zones attached to a network area. Named after the project. Set to null to get a project with no network."

  validation {
    condition     = var.network == null || var.network.prefix_length == null || var.network.prefix_length > 0
    error_message = "network.prefix_length must be a positive IPv4 prefix length."
  }
}

variable "project_tags" {
  type        = map(list(string))
  default     = {}
  description = "Tags applied to the created meshProject. Which tags are mandatory is a property of the meshStack instance, so this is set by the platform team. Leaving it empty on an instance with mandatory project tags makes project creation fail."
}

variable "owner_tag_key" {
  type        = string
  default     = ""
  description = "meshProject tag key that receives the creator's display name. Empty string to set no owner tag."
}

variable "add_random_name_suffix" {
  type        = bool
  default     = true
  description = "Append a five-character random suffix to `name`. The STACKIT project name is the meshProject identifier, so this suffix is what keeps two teams' projects of the same name apart."
}
