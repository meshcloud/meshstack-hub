variable "project_id" {
  type        = string
  nullable    = false
  description = "STACKIT project ID where Object Storage buckets will be created."
}

variable "workload_identity_federation" {
  type = object({
    issuer   = string
    subjects = list(string)
  })
  nullable    = false
  description = "WIF issuer URL and subject list for the meshStack building block identity provider."
}
