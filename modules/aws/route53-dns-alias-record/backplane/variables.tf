variable "hosted_zone_ids" {
  type        = list(string)
  description = "List of Route53 hosted zone IDs that the building block can manage. Example: ['Z07734711DJ9F80W7IUV9', 'ZVJQRTFA77CTX']"
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
