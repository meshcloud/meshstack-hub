variable "project_id" {
  type        = string
  nullable    = false
  description = "STACKIT project ID (existing project) in which the service account will be created."
}

variable "service_account_name" {
  type        = string
  nullable    = false
  description = "Name of the STACKIT service account to create. Must be unique within the project."
}

variable "roles" {
  type        = list(string)
  nullable    = false
  default     = ["reader"]
  description = "STACKIT project roles to grant the service account within the project (e.g. \"reader\", \"editor\")."
}

variable "federated_identities" {
  type = list(object({
    issuer   = string
    subject  = string
    audience = string
  }))
  nullable    = false
  default     = []
  description = <<-EOT
  Workload Identity Federation providers to configure on the service account, so external workloads
  (e.g. GitHub Actions, another cloud) can assume it without a static key. Each entry federates one
  external issuer/subject and pins the token audience:
  - `issuer`: OIDC issuer URL of the external identity provider.
  - `subject`: the exact `sub` claim value the external token must carry.
  - `audience`: the exact `aud` claim value the external token must carry.
  EOT
}
