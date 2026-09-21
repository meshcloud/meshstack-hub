variable "stackit_project_id" {
  type        = string
  nullable    = false
  description = "STACKIT project the Git instance is created in — the platform-native tenant id of the tenant this building block is added to."
}

variable "stackit_region" {
  type        = string
  nullable    = false
  default     = "eu01"
  description = "STACKIT region the Git instance is placed in."
}

variable "instance_name" {
  type        = string
  nullable    = false
  description = "Name of the STACKIT Git instance. It becomes the first label of the instance hostname `<name>.git.onstackit.cloud`, so it is globally unique across all of STACKIT — derive it from something already unique, e.g. a platform identifier carrying a random suffix."

  validation {
    # A hostname label: STACKIT publishes the instance as `<name>.git.onstackit.cloud`, so whatever
    # else the API accepts, a name that is not a valid DNS label cannot be reached.
    condition     = can(regex("^[a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?$", var.instance_name))
    error_message = "instance_name must be a DNS label: lowercase alphanumeric or dashes, not starting or ending with a dash, at most 63 characters."
  }
}

variable "forgejo_organization" {
  type        = string
  nullable    = true
  default     = null
  description = "Forgejo organization to create inside the instance. Created only when `forgejo_token` is also set; leave null to provision the bare instance (phase 1 of the bootstrap, see README)."
}

variable "forgejo_token" {
  type      = string
  nullable  = true
  default   = null
  sensitive = true

  # Optional on purpose — the instance is created without it, and only the Forgejo-side resources
  # wait for it. Today the token is minted by hand and handed back in; the STACKIT Git API can mint
  # it automatically and that path is not wired yet — see the TODO in main.tf.
  description = "Personal Access Token of a bot account in this Forgejo instance, with `write:organization` scope. Leave null on the first run: the instance has to exist before a token can be minted in it."
}
