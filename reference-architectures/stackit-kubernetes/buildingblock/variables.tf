variable "landingzone_building_block_uuid" {
  type        = string
  nullable    = false
  description = "UUID of the STACKIT Landing Zone building block this platform is built on."
}

variable "landingzone_variant" {
  type        = string
  nullable    = false
  default     = "default"
  description = "Key into the landing zone's `landingzone_refs` output. `networked` requires hub-and-spoke networking enabled there."

  validation {
    condition     = contains(["default", "networked"], var.landingzone_variant)
    error_message = "landingzone_variant must be either default or networked."
  }
}

data "meshstack_building_block" "stackit_lz_ref_arch" {
  metadata = {
    uuid = var.landingzone_building_block_uuid
  }
}

# ── meshStack context ──

variable "workspace" {
  type        = string
  nullable    = false
  description = "Identifier of the meshStack workspace that owns the platform, location, landing zones, hosting project and the building block definitions this architecture registers."
}

variable "platform_identifier" {
  type        = string
  nullable    = false
  default     = "ske-platform"
  description = "Identifier of the Kubernetes platform created in meshStack (letters, digits and dashes only). In playground mode a random suffix is appended to it."

  validation {
    condition     = can(regex("^[a-zA-Z0-9-]+$", var.platform_identifier))
    error_message = "platform_identifier must only contain letters, digits, and dashes."
  }
}

variable "use_global_location" {
  type        = bool
  nullable    = false
  default     = false
  description = "Use the global meshStack location instead of creating a dedicated one for this platform."
}

variable "payment_method_identifier" {
  type        = string
  nullable    = false
  description = "Payment method identifier assigned to the hosting meshProject."
}

variable "tags" {
  type = object({
    landingzone           = map(list(string))
    building_block        = map(list(string))
    project               = map(list(string))
    project_owner_tag_key = optional(string, "")
  })
  nullable    = false
  description = <<-EOT
  Tags forwarded to the nested integrations.
  `landingzone` tags are applied to the created SKE landing zones.
  `building_block` tags are applied to the nested building block definitions.
  `project` tags are applied to the hosting meshProject.
  `project_owner_tag_key` names the tag that receives the creator's display name on the hosting project (empty to set none). Set it to the mandatory owner tag your meshStack enforces (e.g. `projectOwner`).
  EOT
}

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
  description = "Creator of the platform, injected by meshStack. Their display name is written to the hosting project's owner tag (see `tags.project_owner_tag_key`)."
}

variable "playground_mode" {
  type        = bool
  nullable    = false
  description = "Deploy a throwaway platform: the platform identifier gets a random suffix so it does not occupy a name for good, and the hosting project and tenant are left destroyable. Set to false for a platform that is actually used."
}

# ── SKE cluster ──

variable "cluster_name" {
  type        = string
  nullable    = true
  default     = null
  description = "Overrides the generated SKE cluster name. 2-11 chars, lowercase alphanumeric or dashes."

  validation {
    condition     = var.cluster_name == null || var.cluster_name == "" || can(regex("^[a-z0-9][a-z0-9-]{0,9}[a-z0-9]$", var.cluster_name))
    error_message = "cluster_name must be 2-11 characters, lowercase alphanumeric or dashes, and not start or end with a dash."
  }
}

variable "cluster_issuer_email" {
  type        = string
  nullable    = true
  default     = null
  description = "Overrides the Let's Encrypt contact email registered for the ACME ClusterIssuer."
}

# ── Forgejo bootstrap (phase 2) ──

# TODO
variable "forgejo_api_token" {
  type        = string
  nullable    = true
  default     = null
  sensitive   = true
  description = "Personal Access Token of a bot account in the Forgejo instance this architecture creates, with `write:organization`, `write:repository` and `read:user` scopes. Leave empty on the first order and fill it in afterwards — see this building block's summary."
}

# ── Hub ──

variable "hub" {
  type = object({
    git_ref   = optional(string, "main")
    bbd_draft = optional(bool, true)
  })
  const   = true
  default = { git_ref = "main", bbd_draft = true }

  description = <<-EOT
  `git_ref`: meshstack-hub reference used to source the nested cluster, git, ingress and kubernetes modules. `const` so it can be interpolated into the module source at init time.
  `bbd_draft`: Forwarded to those nested integrations' `hub.bbd_draft`, so their building block definition draft state tracks this architecture's own release state.
  EOT
}
