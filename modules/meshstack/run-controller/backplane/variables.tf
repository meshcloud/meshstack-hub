variable "api_server_url" {
  type        = string
  description = "URL of the Kubernetes API server that building block runs connect to (example: `https://api.k8s.example.com:6443`)."
}

variable "api_server_ca_certificate" {
  type        = string
  default     = null
  description = "PEM CA bundle that verifies the API server. Defaults to the cluster CA. Set it when the API server presents a certificate signed by another CA."
}

variable "name" {
  type        = string
  default     = "meshstack-run-controller"
  description = "Name of the backplane's namespace, service account, cluster role and admission policy."
}

variable "managed_namespace_label" {
  type        = string
  default     = "io.meshcloud/meshstack.managed-entity"
  description = "Label the meshStack replicator sets to `true` on managed namespaces. The building block may only change objects in namespaces carrying it."
}
