variable "clouds" {
  type        = list(string)
  nullable    = false
  description = "Clouds whose costs are metered, keys of `metering_jobs`."
}

variable "workspace_identifier" {
  type        = string
  nullable    = false
  description = "Workspace that gets the metering project."
}

variable "payment_method" {
  type = object({
    kind = string
    name = string
  })
  nullable    = false
  description = "Payment method of the metering project."
}

variable "project_name" {
  type        = string
  nullable    = false
  description = "Name of the metering project, and so part of its namespace."
}

variable "project_display_name" {
  type        = string
  nullable    = false
  description = "Display name of the metering project in meshPanel."
}

variable "project_tags" {
  type        = map(list(string))
  nullable    = false
  description = "Tags of the metering project."
}

variable "platform_ref" {
  type = object({
    uuid = string
  })
  nullable    = false
  description = "Kubernetes meshPlatform the metering namespace is created on."
}

variable "landing_zone_ref" {
  type = object({
    name = string
  })
  nullable    = false
  description = "Landing zone of the metering namespace."
}

variable "service_account_definition_version_ref" {
  type = object({
    uuid = string
  })
  nullable    = false
  description = "Version of the Kubernetes Service Account definition the metering deploys with."
}

variable "cronjob_definition_version_ref" {
  type = object({
    uuid = string
  })
  nullable    = false
  description = "Version of the Kubernetes CronJob definition every metering job runs as."
}

variable "stackit_workload_identity_definition_version_ref" {
  type = object({
    uuid = optional(string)
  })
  nullable    = false
  description = "Version of the STACKIT Kubernetes Workload Identity definition, `{}` without STACKIT."
}

variable "metering_jobs" {
  type = map(object({
    name  = string
    image = string
    env   = map(string)
    service_account_token = optional(object({
      audience   = string
      mount_path = string
    }))
    stackit_workload_identity = bool
  }))
  nullable    = false
  description = "Image, environment and service account token of each cloud's metering CronJob, keyed by the cloud name offered in `clouds`."
}

variable "metering_secrets" {
  type        = map(map(string))
  nullable    = false
  sensitive   = true
  ephemeral   = true
  description = "Secret environment variables of each cloud's metering CronJob."
}

variable "credentials_revision" {
  type        = number
  nullable    = false
  description = "Changes with `metering_secrets`, so the CronJob building blocks write them anew to their Kubernetes secrets."
}

variable "schedule" {
  type        = string
  nullable    = false
  description = "Cron schedule of every metering job."
}
