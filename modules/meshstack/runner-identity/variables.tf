variable "cloud" {
  type        = string
  nullable    = false
  description = "The token the building block signs in with: `aws`, `azure` or `gcp`. A STACKIT building block uses `azure` and an OTC building block uses `gcp`, each as a generic OIDC token."

  validation {
    condition     = contains(["aws", "azure", "gcp"], var.cloud)
    error_message = "cloud must be one of aws, azure or gcp."
  }
}

# No default, so that a caller cannot forget to forward `var.meshstack.runner_ref`.
variable "runner_ref" {
  type = object({
    kind = string
    uuid = string
  })
  description = "The runner to look up, as given in `var.meshstack.runner_ref`. Null looks up the default runner."
}

variable "trusted_runner_refs" {
  type = list(object({
    kind = string
    uuid = string
  }))
  default     = []
  nullable    = false
  description = "Other runners to trust besides the current one, as given in `var.meshstack.trusted_runner_refs`. List the previous runner here while building blocks still use a version that runs on it."
}

variable "versions" {
  type = map(object({
    workload_identity_federation = object({
      issuer  = string
      subject = string
      aws     = object({ audience = string })
      azure   = object({ audience = string })
      gcp     = object({ audience = string })
    })
  }))
  default     = {}
  nullable    = false
  description = "The `versions` of the building block definition. The module reads only `workload_identity_federation` of each version, which has the subject that its runs present. Only the output `identities` reads it."
}
