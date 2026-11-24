variable "building_block_definition_uuid" {
  type        = string
  nullable    = false
  description = "UUID of the Temporary Group Access definition whose expired building blocks the sweeper deletes."
}

variable "display_name" {
  type        = string
  nullable    = false
  default     = "meshStack Temporary Group Access"
  description = "Display name of the access definition. The API key, the sweeper definition and the sweeper building block are named after it, so several deployments stay apart."
}

variable "api_key_lifetime_days" {
  type        = number
  nullable    = false
  default     = 90
  description = "How long the sweeper's API key is valid. meshStack requires an expiry and caps how far out it may sit. The expiry rolls forward on the first apply past half this many days; past it, the sweeper fails to authenticate and expired blocks stay."

  validation {
    condition     = var.api_key_lifetime_days >= 2
    error_message = "api_key_lifetime_days must be at least 2: the expiry rolls forward at half the lifetime, and a rotation window is measured in whole days."
  }
}

variable "meshstack" {
  type = object({
    owning_workspace_identifier = string
    tags                        = optional(map(list(string)), {})
    runner_ref = optional(object({
      kind = string
      uuid = string
    }))
  })
  description = "Shared meshStack context, see docs."
}

variable "hub" {
  type = object({
    git_ref   = optional(string, "main")
    bbd_draft = optional(bool, true)
  })
  default = {
    git_ref   = "main"
    bbd_draft = true
  }
  description = <<-EOT
  `git_ref`: Hub release reference the sweeper definition runs. Set to a tag (e.g. 'v1.2.3') or branch or commit sha of the meshstack-hub repo.
  `bbd_draft`: If true, the sweeper definition version is kept in draft mode.
  EOT
}
