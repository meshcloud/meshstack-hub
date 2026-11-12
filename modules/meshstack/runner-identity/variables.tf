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
