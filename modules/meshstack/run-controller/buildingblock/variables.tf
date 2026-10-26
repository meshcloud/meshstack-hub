variable "namespace" {
  type        = string
  description = "Kubernetes namespace of the tenant the run-controller runs in and starts its Jobs in."
  nullable    = false
}

variable "workspace_identifier" {
  type        = string
  description = "meshStack workspace that owns the runner."
  nullable    = false
}

variable "project_identifier" {
  type        = string
  description = "meshStack project of the tenant. The runner is named after it."
  nullable    = false
}

variable "runner_api_key" {
  type = object({
    client_id     = string
    client_secret = string
  })
  sensitive   = true
  ephemeral   = true
  description = "API key the runner polls meshStack with."
  nullable    = false
}

variable "runner_api_key_version" {
  type        = string
  description = "Hash of the runner's API key. A new value rewrites the runner's config."
  nullable    = false
}

variable "kubernetes_api" {
  type = object({
    server                 = string
    cluster_ca_certificate = string
    token                  = string
  })
  sensitive   = true
  ephemeral   = true
  description = "Kubernetes API server connection data."
  nullable    = false
}

variable "image" {
  type        = string
  description = "Image of the run-controller."
  nullable    = false
}

variable "job_image" {
  type        = string
  description = "Image of the Jobs that execute the runs. Without a tag, the run-controller appends its own version."
  nullable    = false
}
