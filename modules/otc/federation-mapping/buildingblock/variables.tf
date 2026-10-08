variable "region" {
  type        = string
  default     = "eu-de"
  nullable    = false
  description = "T Cloud Public region of the management project and the mapping bucket."
}

variable "project_id" {
  type        = string
  nullable    = false
  description = "ID of the management project the function runs in."
}

variable "mapping_bucket" {
  type        = string
  nullable    = false
  description = "OBS bucket project building blocks record their group membership in, as `mappings/<project>.json`."
}

variable "identity_provider_name" {
  type        = string
  nullable    = false
  description = "Federated identity provider whose mapping the function rebuilds."
}

variable "email_attribute" {
  type        = string
  default     = "email"
  nullable    = false
  description = "SAML attribute or OIDC claim that carries the user's email address, matched against the recorded emails."
}

variable "name" {
  type        = string
  default     = "meshstack-idp-mapping"
  nullable    = false
  description = "Name of the function and its agency. Agency names are unique across the domain."
}

variable "resync_schedule" {
  type        = string
  default     = "@every 1h"
  nullable    = false
  description = "How often the function rebuilds the mapping regardless of bucket events, as a FunctionGraph cron schedule."
}
