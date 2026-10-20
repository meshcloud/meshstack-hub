variable "api_server_url" {
  type        = string
  description = "URL of the Kubernetes API server that building block runs and GitHub Actions connect to (example: `https://api.k8s.example.com:6443`)."
}

variable "api_server_ca_certificate" {
  type        = string
  default     = null
  description = "PEM CA bundle that verifies the API server. Defaults to the cluster CA the service account token carries; set it when the API server presents a certificate signed by another CA."
}

variable "namespace" {
  type        = string
  default     = "meshstack-github-connector"
  description = "Namespace the backplane creates for the building block's service account."
}

variable "service_account_name" {
  type        = string
  default     = "meshstack-github-connector"
  description = "Name of the service account, cluster role and cluster role binding the building block runs with."
}

variable "tenant_namespace_label" {
  type        = string
  default     = "io.meshcloud/meshstack.managed-entity"
  description = "Label the meshStack replicator sets to `true` on tenant namespaces. The building block may only change objects in namespaces carrying it."
}
