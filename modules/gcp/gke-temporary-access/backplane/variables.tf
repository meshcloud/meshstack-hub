variable "project_id" {
  description = "GCP project ID that contains the GKE cluster."
  type        = string
  nullable    = false
}

variable "forbidden_namespaces" {
  description = "Namespace denylist. Defaults to `kube-*`, `gke-*` and `gmp-*`. An explicit list replaces these defaults. The cleanup namespace is always blocked, even with `[]`. A trailing `*` matches a prefix."
  type        = list(string)
  default     = ["kube-*", "gke-*", "gmp-*"]

  nullable = false
}

variable "cluster_role" {
  description = "Existing ClusterRole assigned to users by the building block."
  type        = string
  default     = "view"
  nullable    = false
}

variable "cleanup_namespace" {
  description = "Namespace created for the CronJob that removes expired RoleBindings."
  type        = string
  default     = "gke-temporary-access"
  nullable    = false
}

variable "cleanup_image" {
  description = "Container image used by the cleanup CronJob. It must include `bash`, `date` and `kubectl`."
  type        = string
  default     = "alpine/k8s:1.37.1"
  nullable    = false
}

variable "service_account_id" {
  description = "Account ID of the building block's Google service account. It also prefixes the in-cluster ClusterRoles and admission policy, so it must be unique per project and per cluster."
  type        = string
  default     = "buildingblock-gke-access-sa"
}

variable "workload_identity_federation" {
  description = "Workload identity federation settings describing the building block runner."
  type = object({
    workload_identity_pool_identifier = string
    subject_token_file_path           = string
  })
  nullable = false
}

# Keep trust settings separate to avoid a dependency cycle through `credentials_json`.
variable "workload_identity_federation_trust" {
  description = "The building block runner's OIDC issuer and audience, and the subject claims it accepts."
  type = object({
    issuer   = string
    audience = string
    subjects = list(string)
  })
  nullable = false
}
