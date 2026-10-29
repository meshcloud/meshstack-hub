variable "namespace" {
  type        = string
  description = "Kubernetes namespace of the tenant the run-controller runs in and starts its Jobs in."
}

variable "workspace_identifier" {
  type        = string
  description = "meshStack workspace that owns the runner."
}

variable "project_identifier" {
  type        = string
  description = "meshStack project of the tenant. The runner is named after it."
}

variable "runner_api_key_client_id" {
  type        = string
  description = "Client id of the API key the runner polls meshStack with."
}

variable "runner_api_key_client_secret" {
  type        = string
  sensitive   = true
  description = "Client secret of the runner's API key."
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

variable "image" {
  type        = string
  description = "Image of the run-controller."
}

variable "job_image" {
  type        = string
  description = "Image of the Jobs that execute the runs. Without a tag, the run-controller appends its own version."
}
