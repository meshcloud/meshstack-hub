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
    landingzone    = map(list(string))
    building_block = map(list(string))
    project        = map(list(string))
  })
  nullable    = false
  description = <<-EOT
  Tags forwarded to the nested integrations.
  `landingzone` tags are applied to the created SKE landing zones.
  `building_block` tags are applied to the nested building block definitions.
  `project` tags are applied to the hosting meshProject.
  EOT
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

variable "service_account_bbd_version_ref" {
  type        = string
  nullable    = false
  description = "Version uuid of the STACKIT Service Account building block definition (registered by the STACKIT Landing Zone, exposed as its `service_account_bbd_version_uuid` output). Ordered on the hosting project to mint the automation identity the cluster deploys as."
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
