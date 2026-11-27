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

variable "runner_uuid" {
  type        = string
  default     = null
  description = "The uuid of the runner that `workload_identity_federation` describes. If it differs from `original_runner_uuid`, the identity provider name ends with the first 8 characters of this uuid."
}

variable "original_runner_uuid" {
  type        = string
  default     = null
  description = "The uuid of the runner in `meshstack.original_runner_ref`. The identity provider for this runner gets the name `name` without a suffix. Null means the runner in `runner_uuid`."
}

variable "trusted_runner_identities" {
  type = list(object({
    runner_uuid = string
    issuer      = string
    audience    = string
    subject     = string
  }))
  default     = []
  nullable    = false
  description = "One entry per trusted runner, with the issuer, audience and subject of its tokens. The backplane creates one identity provider for each. Pass `trusted_identities` of the [runner-identity module](../../meshstack/runner-identity). The plan fails for a runner that no version uses. If the same apply changes the runner, the apply fails instead."
}

variable "domain_roles" {
  type        = list(string)
  default     = []
  nullable    = false
  description = "IAM system roles granted to the group on the domain, by role `name`."
}

variable "project_roles" {
  type        = list(string)
  default     = []
  nullable    = false
  description = "IAM system roles and policies granted to the group on all projects, by `name` (e.g. `system_all_12` for RDS FullAccess), not display name."
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
