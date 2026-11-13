variable "name" {
  description = "Name of the CronJob and of the Kubernetes service account its pods run as."
  type        = string
  nullable    = false

  validation {
    condition     = can(regex("^[a-z0-9]([-a-z0-9]{0,50}[a-z0-9])?$", var.name))
    error_message = "name must be at most 52 lowercase letters, digits and dashes, and not start or end with a dash."
  }
}

variable "image" {
  description = "Container image the job runs, e.g. `ghcr.io/example/report:1.2.3`. It is pulled on every run."
  type        = string
  nullable    = false
}

variable "schedule" {
  description = "Cron schedule of the job, e.g. `0 * * * *`."
  type        = string
  nullable    = false
}

variable "env" {
  description = "Environment variables of the container."
  type        = map(string)
  nullable    = false
}

variable "secret_env" {
  description = "Environment variables of the container that are kept in a Kubernetes secret."
  type        = map(string)
  default     = null
  sensitive   = true
  ephemeral   = true
}

variable "secret_env_revision" {
  description = "Increase to write a changed `secret_env` to the Kubernetes secret."
  type        = number
  nullable    = false

  validation {
    condition     = var.secret_env_revision >= 1
    error_message = "secret_env_revision must be at least 1, or the kubernetes provider writes the secret empty."
  }
}

variable "service_account_token" {
  description = "Mounts a token of the job's Kubernetes service account with this audience at `<mount_path>/token`, for workload identity federation with a cloud."
  type = object({
    audience   = string
    mount_path = string
  })
  default = null
}

variable "resources" {
  description = "CPU and memory requests and limits of the container."
  type = object({
    cpu_request    = string
    memory_request = string
    cpu_limit      = string
    memory_limit   = string
  })
  nullable = false
}

variable "kubeconfig" {
  description = "Kubeconfig (YAML) of a service account that may manage service accounts, Secrets and CronJobs in `namespace`."
  type        = string
  sensitive   = true
  ephemeral   = true
  nullable    = false
}

variable "namespace" {
  description = "Kubernetes namespace of the tenant the CronJob runs in."
  type        = string
  nullable    = false
}
