variable "kubeconfig_admin" {
  description = "Admin kubeconfig object for the target cluster. Used to configure the kubernetes provider and build the scoped output kubeconfig."
  type        = any
  sensitive   = true
}

variable "service_account_name" {
  description = "Name for the building block service account and associated RBAC resources."
  type        = string
  default     = "meshstack-manifest-bb"
}

variable "namespace" {
  description = "Namespace in which the service account is created (e.g. a dedicated platform namespace)."
  type        = string
  default     = "kube-system"
}
