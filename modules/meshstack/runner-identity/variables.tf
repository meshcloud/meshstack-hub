variable "cloud" {
  type        = string
  nullable    = false
  description = "Which token the runs present: `aws`, `azure` or `gcp`. A STACKIT building block presents the `azure` token as a generic OIDC token. An OTC building block does the same with the `gcp` token."

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
  description = "The runners in `var.meshstack.trusted_runner_refs`. List a runner while a building block is on an older version that uses it."
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
  description = "The `versions` attribute of the building block definition. The module takes the subject of each entry in `identities` from it. Omit it if you do not read `identities`."
}
