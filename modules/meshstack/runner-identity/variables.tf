variable "cloud" {
  type        = string
  nullable    = false
  description = "The section of the runner's workload identity federation that the building block uses: `aws`, `azure` or `gcp`. A STACKIT building block uses `azure`, and an OTC building block uses `gcp`."

  validation {
    condition     = contains(["aws", "azure", "gcp"], var.cloud)
    error_message = "cloud must be one of aws, azure or gcp."
  }
}

variable "runner_ref" {
  type = object({
    kind = string
    uuid = string
  })
  default     = null
  description = "The runner the definition's latest version runs on, as passed to `version_spec.runner_ref`. Set to null to select the meshStack hosted runner."
}

variable "trusted_runner_refs" {
  type = list(object({
    kind = string
    uuid = string
  }))
  default     = []
  nullable    = false
  description = "Other runners to trust besides `runner_ref`. List the previous runner here while building blocks still use versions that run on it."
}

variable "versions" {
  type = map(object({
    workload_identity_federation = object({
      issuer  = string
      subject = string
    })
  }))
  nullable    = false
  description = "The `versions` of the building block definition. Each version has the subject that its runs present."
}
