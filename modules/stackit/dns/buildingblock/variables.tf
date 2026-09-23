variable "stackit_project_id" {
  type        = string
  nullable    = false
  description = "STACKIT project the zone is created in."
}

variable "stackit_region" {
  type        = string
  nullable    = false
  description = "STACKIT region the zone is placed in."
}

variable "subdomain" {
  type        = string
  nullable    = false
  description = "Label this zone occupies under `parent_domain`, e.g. `my-platform` for `my-platform.stackit.run`."

  validation {
    condition     = can(regex("^[a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?$", var.subdomain))
    error_message = "subdomain must be a DNS label: lowercase letters, digits and dashes, not starting or ending with a dash, at most 63 characters."
  }
}

variable "parent_domain" {
  type        = string
  nullable    = false
  description = "Domain this zone is created under."
}

variable "contact_email" {
  type        = string
  nullable    = false
  description = "Address in the zone's SOA record, where a resolver problem is reported."
}

variable "default_ttl" {
  type        = number
  nullable    = false
  description = "Default TTL in seconds for records in this zone."
}

variable "wildcard_target_ip" {
  type        = string
  nullable    = true
  default     = null
  description = "IPv4 address the `*.<zone>` A record points at. Null creates no record."

  validation {
    condition     = var.wildcard_target_ip == null || can(regex("^([0-9]{1,3}\\.){3}[0-9]{1,3}$", var.wildcard_target_ip))
    error_message = "wildcard_target_ip must be an IPv4 address."
  }
}
