variable "hosted_zone_ids" {
  type        = list(string)
  description = "List of Route53 hosted zone IDs that the building block can manage. Example: '<hosted_zone_id_1>', '<hosted_zone_id_2>']"
}

variable "workload_identity_federation" {
  type = object({
    issuer   = string,
    audience = string,
    subjects = list(string)
  })
  default     = null
  description = "Set these options to add a trusted identity provider from meshStack to allow workload identity federation for authentication which can be used instead of access keys. Supports multiple subjects and wildcard patterns (e.g., 'system:serviceaccount:namespace:*')."
}

variable "create_oidc_provider" {
  type        = bool
  default     = true
  description = "Set to false if the OIDC provider for the meshStack issuer already exists in this AWS account (e.g., created by another backplane). The existing provider will be looked up by URL instead of created."
}
