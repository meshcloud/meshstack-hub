variable "platform_identifier" {
  description = "Full identifier `<platform>.<location>` of the STACKIT meshPlatform whose tenants receive the usage reports, e.g. `stackit.global`."
  type        = string
  nullable    = false
}

variable "meshstack_api_user" {
  description = "Username of the meshStack API user that reads meshTenants and writes usage reports. The metering API accepts only API users, no API keys."
  type        = string
  nullable    = false
}

variable "meshstack_api_secret" {
  description = "Password of the meshStack API user."
  type        = string
  sensitive   = true
  ephemeral   = true
  nullable    = false
}

variable "credentials_revision" {
  description = "Increase to write a changed API user password to the Kubernetes secret."
  type        = number
  nullable    = false

  validation {
    condition     = var.credentials_revision >= 1
    error_message = "credentials_revision must be at least 1, or the kubernetes provider writes the secret empty."
  }
}

variable "schedule" {
  description = "Cron schedule of the metering job. Each run re-submits the full current month."
  type        = string
  nullable    = false
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

variable "meshstack_meshfed_url" {
  description = "meshfed API endpoint of the meshStack that receives the usage reports."
  type        = string
  nullable    = false
}

variable "meshstack_kraken_url" {
  description = "Kraken API endpoint of the same meshStack."
  type        = string
  nullable    = false
}

variable "stackit_organization_id" {
  description = "STACKIT organization whose project costs are collected."
  type        = string
  nullable    = false
}

variable "stackit_project_id" {
  description = "STACKIT project of the metering service account."
  type        = string
  nullable    = false
}

variable "stackit_metering_service_account_email" {
  description = "STACKIT service account with read access to the organization's costs, which the CronJob acts as."
  type        = string
  nullable    = false
}

variable "kubernetes_oidc_issuer" {
  description = "OIDC issuer of the cluster's service account tokens, which STACKIT must be able to reach."
  type        = string
  nullable    = false
}

variable "image_tag" {
  description = "Tag of the `ghcr.io/meshcloud/mesh-custom-metering/mesh-metering-stackit` image."
  type        = string
  nullable    = false
}
