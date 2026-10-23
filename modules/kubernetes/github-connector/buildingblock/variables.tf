variable "namespace" {
  type        = string
  description = "Namespace of the tenant the connector deploys into."
}

variable "kubernetes_api" {
  type = object({
    server                 = string
    cluster_ca_certificate = string
    token                  = string
  })
  sensitive   = true
  description = "API server URL, PEM CA bundle and token of the connector backplane's service account."
}

variable "github_repo" {
  type        = string
  description = "Name of the GitHub repository to connect, within the organization the GitHub App is installed in."
}

variable "github_environment_name" {
  type        = string
  description = "GitHub environment that receives the deployment credentials of this namespace."
}
