variable "project_id" {
  description = "GCP project ID that contains the GKE cluster."
  type        = string
  nullable    = false
}

variable "forbidden_namespaces" {
  description = "Namespaces developers can't request access to, on top of the system namespaces and `cleanup_namespace`. A trailing `*` matches a prefix."
  type        = set(string)
  default     = []
  nullable    = false
}

variable "cluster_role" {
  description = "Existing ClusterRole the building block binds developers to in the chosen namespace."
  type        = string
  default     = "view"
  nullable    = false
}

variable "cleanup_namespace" {
  description = "Namespace the backplane creates for the CronJob that removes expired RoleBindings."
  type        = string
  default     = "gke-temporary-access"
  nullable    = false
}

variable "cleanup_image" {
  description = "Image of the cleanup CronJob. It needs bash, date and kubectl."
  type        = string
  default     = "alpine/k8s:1.37.1"
  nullable    = false
}

variable "service_account_id" {
  description = "Account ID of the service account the building block runs as. Also prefixes the in-cluster ClusterRole, so it must be unique per cluster."
  type        = string
  default     = "buildingblock-gke-access-sa"
}

variable "iam_propagation_delay_seconds" {
  description = "Seconds to wait after granting the building block's IAM roles before publishing its credentials. GCP IAM is eventually consistent, and Google's guidance is to allow two to seven minutes before retrying a denied impersonation. Set to 0 if the backplane is always provisioned well before any building block run."
  type        = number
  default     = 180
}

variable "workload_identity_federation" {
  description = "Workload identity federation settings describing the building block runner."
  type = object({
    workload_identity_pool_identifier = string
    subject_token_file_path           = string
  })
  nullable = false
}

# Apart, because Terraform depends on a whole variable rather than the attribute read: these come
# from the building block definition's `version_latest`, and reading them next to the pool identifier would
# put `credentials_json` behind the definition that consumes it.
variable "workload_identity_federation_trust" {
  type = object({
    issuer   = string
    audience = string
    subjects = list(string)
  })
  nullable    = false
  description = "What the pool provider trusts: the runner's OIDC issuer and audience, and the subject claims it accepts, each matched exactly. Take them from `version_latest.workload_identity_federation` of the building block definitions that run here."
}
