variable "parent_container_id" {
  type        = string
  nullable    = false
  description = "The parent container ID (organization or folder) where the project will be created."
}

variable "environment" {
  type        = string
  default     = null
  description = "The environment type (production, staging, development). If not set, uses parent_container_id directly."
}

variable "parent_container_ids" {
  type = object({
    production  = optional(string)
    staging     = optional(string)
    development = optional(string)
  })
  default     = {}
  description = "Parent container IDs for different environments. If environment is set, the corresponding container ID will be used."
}

variable "project_name" {
  type        = string
  nullable    = false
  description = "The name of the StackIt project to create."
}

variable "project_owner_email" {
  type        = string
  nullable    = false
  description = <<-EOT
  Email of the initial owner of the created project. STACKIT applies this only at creation, as a
  `members` entry with the `owner` role, and ignores any later change.
  EOT
}

variable "labels" {
  type        = map(string)
  nullable    = false
  description = "Labels to apply to the project. The `networkArea` label is added from `network_area_ids`."
}

variable "landing_zone" {
  type        = string
  nullable    = false
  description = "Identifier of the landing zone of the tenant the project is created for."
}

variable "network_area_ids" {
  type        = map(string)
  nullable    = false
  description = "STACKIT network area ID per landing zone identifier. A project in one of these landing zones is placed in its network area, and a STACKIT Network building block is ordered for it."
}

# The definition hides this input outside the landing zones of `network_area_ids`, and a hidden input
# is not sent.
variable "network" {
  type = object({
    prefix_length    = optional(number, 25)
    ipv4_nameservers = optional(list(string), [])
  })
  default     = {}
  nullable    = false
  description = "Routed network ordered for the project when its landing zone has a network area. An empty `ipv4_nameservers` inherits the network area's default nameservers."

  validation {
    # meshStack rejects `format` in the input's json_schema, so the form cannot check this.
    condition     = alltrue([for ns in var.network.ipv4_nameservers : can(cidrnetmask("${ns}/32"))])
    error_message = "network.ipv4_nameservers must only contain IPv4 addresses."
  }
}

variable "tenant_uuid" {
  type        = string
  nullable    = false
  description = "UUID of the meshStack tenant the project is created for. The network building block is ordered on it."
}

# Only declared on the definition when a landing zone has a network area. `content_hash` changes with
# a draft version's content, so the network re-runs on it.
variable "network_definition_version_ref" {
  type = object({
    uuid         = string
    content_hash = optional(string)
  })
  default     = null
  description = "Version of the STACKIT Network definition the project's network is ordered from."
}

variable "users" {
  description = "List of users from the authoritative system. Each user's `roles` are meshStack roles that are mapped to STACKIT project roles via `role_mapping`."
  type = list(object({
    meshIdentifier = string
    username       = string
    firstName      = string
    lastName       = string
    email          = string
    euid           = string
    roles          = list(string)
  }))
  nullable = false
}

variable "role_mapping" {
  type        = map(list(string))
  description = "Maps meshStack roles from `users[*].roles` to STACKIT project roles. Values can be built-in STACKIT roles or custom STACKIT role names. Unknown meshStack roles are ignored."

  nullable = false
}


variable "organization_id" {
  type        = string
  nullable    = false
  default     = ""
  description = "STACKIT organization where project users are looked up before their roles are granted; users STACKIT does not know are skipped and listed in the summary. Needs `iam.member.get` on the organization. Empty grants every user's roles without a lookup."
}
