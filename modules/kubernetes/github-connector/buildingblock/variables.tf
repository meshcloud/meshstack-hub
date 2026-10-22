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

variable "deploy_branch" {
  type        = string
  default     = "main"
  description = "Branch whose workflow deploys into this namespace. The connector dispatches the workflow on it once its credentials are in place."
}

variable "workflow_filename" {
  type        = string
  default     = ""
  description = "Workflow to dispatch on `deploy_branch` after setup (example: `k8s-deploy.yml`). It must declare `on: workflow_dispatch`. Empty skips the dispatch."
}
