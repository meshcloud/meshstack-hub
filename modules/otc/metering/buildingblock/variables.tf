variable "schedule" {
  description = "Cron schedule of the metering job. Each run re-submits the full current month."
  type        = string
  nullable    = false
}

variable "kubeconfig" {
  description = "Kubeconfig (YAML) of a service account that may manage Secrets and CronJobs in `namespace`."
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

variable "platform_identifier" {
  description = "Full identifier `<platform>.<location>` of the T Cloud Public meshPlatform whose tenants receive the usage reports, e.g. `otc.global`."
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

variable "tcloud_api_token" {
  description = "API key of the T Cloud Financial Dashboard with security level `Admin`."
  type        = string
  sensitive   = true
  ephemeral   = true
  nullable    = false
}

variable "credentials_revision" {
  description = "Changes with the API user password or the Financial Dashboard API key, so the run writes them anew to the Kubernetes secret."
  type        = number
  nullable    = false

  validation {
    condition     = var.credentials_revision >= 1
    error_message = "credentials_revision must be at least 1, or the kubernetes provider writes the secret empty."
  }
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

variable "tcloud_contract_ids" {
  description = "T Cloud contract numbers to read. Empty reads every contract the API key sees."
  type        = list(string)
  nullable    = false
}

variable "image_tag" {
  description = "Tag of the `ghcr.io/meshcloud/mesh-custom-metering/mesh-metering-tcloud` image."
  type        = string
  nullable    = false
}
