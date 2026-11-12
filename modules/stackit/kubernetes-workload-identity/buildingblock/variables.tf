variable "kubernetes_service_account_name" {
  description = "Kubernetes service account in `namespace` whose tokens may act as the STACKIT service account. It need not exist yet."
  type        = string
  nullable    = false
}

variable "audience" {
  description = "Audience the workload requests for its service account token."
  type        = string
  nullable    = false
}

variable "stackit_project_id" {
  description = "STACKIT project of the workload service account."
  type        = string
  nullable    = false
}

variable "workload_service_account_email" {
  description = "STACKIT service account the Kubernetes workload acts as."
  type        = string
  nullable    = false
}

variable "kubernetes_oidc_issuer" {
  description = "OIDC issuer of the cluster's service account tokens, which STACKIT must be able to reach."
  type        = string
  nullable    = false
}

variable "namespace" {
  description = "Kubernetes namespace of the tenant."
  type        = string
  nullable    = false
}
