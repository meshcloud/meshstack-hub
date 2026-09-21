# ── meshStack context ──

variable "workspace" {
  type        = string
  nullable    = false
  description = "Identifier of the meshStack workspace that owns the platform, location, landing zones, hosting project and the building block definitions this architecture registers."
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

# ── STACKIT self-hosting ──

variable "host_platform_identifier" {
  type        = string
  nullable    = false
  description = "Full `<platform>.<location>` identifier of the existing STACKIT Project platform (e.g. from the STACKIT Landing Zone) on which the cluster's hosting project is provisioned as a meshStack tenant."
}

variable "host_landing_zone_name" {
  type        = string
  nullable    = false
  description = "Name of the landing zone on the host STACKIT platform that the hosting tenant is placed in."
}

variable "landingzone_building_block_uuid" {
  type        = string
  nullable    = false
  description = "UUID of the deployed STACKIT Landing Zone building block this platform is built on. Read at order time for the foundation project and landing-zone folder the registered definitions' backplanes deploy into, and for the bootstrap service account credential this run applies as."
}

# ── Forgejo bootstrap (phase 2) ──

variable "forgejo_api_token" {
  type      = string
  nullable  = true
  default   = null
  sensitive = true

  # The instance has to exist before a token can be created in it, so this cannot be filled in on
  # the first order. Leaving it null is phase 1; the summary then prints where to go and what to
  # mint. An automatic mint through the STACKIT Git API would feed the same code path — see the
  # TODO in main.tf — so this input stays as the override and the fallback either way.
  description = "Personal Access Token of a bot account in the Forgejo instance this architecture creates, with `write:organization`, `write:repository` and `read:user` scopes. Leave empty on the first order and fill it in afterwards — see this building block's summary."
}

variable "harbor_username" {
  type        = string
  nullable    = true
  default     = null
  sensitive   = true
  description = "Username of a STACKIT Harbor pull robot account, handed to the Forgejo connector so application pods can pull private images. Optional: the Harbor project is shared across STACKIT customers and we hold robot credentials for it rather than admin rights, so nothing here creates them. Without them the connector still works for public images."
}

variable "harbor_password" {
  type        = string
  nullable    = true
  default     = null
  sensitive   = true
  description = "Secret of the STACKIT Harbor pull robot account named in `harbor_username`."
}

# ── SKE cluster ──

variable "cluster_name" {
  type        = string
  nullable    = false
  default     = "starterkit"
  description = "Name of the SKE cluster (2-11 chars, lowercase alphanumeric or dashes, no leading/trailing dash)."

  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9-]{0,9}[a-z0-9]$", var.cluster_name))
    error_message = "cluster_name must be 2-11 characters, lowercase alphanumeric or dashes, and not start or end with a dash."
  }
}

variable "cluster_issuer_email" {
  type        = string
  nullable    = false
  default     = "ske@meshcloud.io"
  description = "Contact email registered with Let's Encrypt for the ACME ClusterIssuer installed on the cluster."
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
  `git_ref`: meshstack-hub reference used to source the nested cluster and platform-services modules. `const` so it can be interpolated into the module source at init time.
  `bbd_draft`: Forwarded to those nested integrations' `hub.bbd_draft`, so their building block definition draft state tracks this architecture's own release state.
  EOT
}
