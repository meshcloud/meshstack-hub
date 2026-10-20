variable "name" {
  type        = string
  nullable    = false
  description = "Name of the identity provider, the IAM group and the virtual user the building block signs in as. Unique across the domain."
}

variable "workload_identity_federation" {
  type = object({
    issuer   = string
    subject  = string
    audience = string
  })
  nullable    = false
  description = "Identity the building block's runs present: the meshStack issuer, the definition's subject, and the audience of the token prerun.sh exchanges."
}

variable "domain_roles" {
  type        = list(string)
  default     = []
  nullable    = false
  description = "IAM system roles granted to the group on the domain, by role `name`."
}

variable "policies" {
  type = map(object({
    actions = list(string)
    scope   = string
  }))
  default     = {}
  nullable    = false
  description = <<-EOT
  Custom policies granted to the group, by a short key that names the role. `scope` is where it applies:
  `domain` for global services such as IAM, `obs` for OBS, `region` for the region's own project the
  provider targets, and `all_projects` for every project, including those created later.
  EOT

  validation {
    condition     = alltrue([for p in values(var.policies) : contains(["domain", "obs", "region", "all_projects"], p.scope)])
    error_message = "Each policy's scope must be one of domain, obs, region or all_projects."
  }
}
