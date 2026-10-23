variable "namespace" {
  type        = string
  description = "The Kubernetes namespace that will be deployed to."
}

variable "kubernetes_api" {
  type = object({
    server                 = string
    cluster_ca_certificate = string
    token                  = string
  })
  sensitive   = true
  description = "Kubernetes API server connection data."
}

variable "github_repo" {
  type        = string
  description = "Name of the GitHub repository to connect."
}

variable "github_environment_name" {
  type        = string
  description = "GitHub environment that will be created for this connection."
}
