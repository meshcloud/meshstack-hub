variable "kubernetes" {
  type = object({
    platform_identifier              = string
    landing_zone_name                = string
    cluster_roles                    = list(string)
    service_account_bbd_display_name = optional(string)
  })
  nullable    = false
  description = "Kubernetes meshPlatform the metering namespaces are created on, as `<platform>.<location>`, its landing zone, and the ClusterRoles the Kubernetes Service Account definition offers. The admin kubeconfig of its cluster comes as the file `kubeconfig.yaml`."

  validation {
    condition     = contains(var.kubernetes.cluster_roles, "edit")
    error_message = "kubernetes.cluster_roles must contain edit, which the metering service account is ordered with."
  }
}

variable "metering" {
  type = object({
    meshfed_url = string
    kraken_url  = string
    api_user    = string
    schedule    = string
  })
  nullable    = false
  description = "meshStack endpoints the usage reports go to, the API user that submits them, and the cron schedule of every metering job."
}

variable "metering_api_secret" {
  type        = string
  nullable    = false
  sensitive   = true
  description = "Password of the meshStack API user."
}

variable "metering_project" {
  type = object({
    name         = string
    display_name = string
    tags         = list(object({ key = string, values = list(string) }))
  })
  nullable    = false
  description = "Name, display name and tags of the meshProject every Platform Metering order creates. The meshPanel form sends the tags as a list of {key, values} entries."
}

variable "stackit_enabled" {
  type        = bool
  nullable    = false
  description = "Offer the metering of STACKIT."
}

variable "stackit" {
  type = object({
    platform_identifier    = string
    organization_id        = string
    project_id             = string
    kubernetes_oidc_issuer = string
    image_tag              = optional(string, "latest")
  })
  default     = null
  description = "STACKIT meshPlatform, organization and project of the metering service accounts, and the OIDC issuer of the cluster's service account tokens. Set with `stackit_enabled`."

  validation {
    condition     = !var.stackit_enabled || var.stackit != null
    error_message = "stackit_enabled needs stackit."
  }
}

variable "stackit_service_account_key" {
  type        = string
  default     = null
  sensitive   = true
  ephemeral   = true
  description = "Key of a STACKIT service account that may create service accounts in `stackit.project_id` and assign roles on the organization. Set with `stackit_enabled`."

  validation {
    condition     = !var.stackit_enabled || var.stackit_service_account_key != null
    error_message = "stackit_enabled needs stackit_service_account_key."
  }
}

variable "tcloud_enabled" {
  type        = bool
  nullable    = false
  description = "Offer the metering of T Cloud Public."

  validation {
    condition     = var.stackit_enabled || var.tcloud_enabled
    error_message = "Offer the metering of at least one cloud."
  }
}

variable "tcloud" {
  type = object({
    platform_identifier = string
    contract_ids        = optional(list(string), [])
    image_tag           = optional(string, "latest")
  })
  default     = null
  description = "T Cloud Public meshPlatform and the contracts to read. Set with `tcloud_enabled`."

  validation {
    condition     = !var.tcloud_enabled || var.tcloud != null
    error_message = "tcloud_enabled needs tcloud."
  }
}

variable "tcloud_api_token" {
  type        = string
  default     = null
  sensitive   = true
  description = "API key of the T Cloud Financial Dashboard with security level `Admin`, valid for at most 90 days. Set with `tcloud_enabled`."

  validation {
    condition     = !var.tcloud_enabled || var.tcloud_api_token != null
    error_message = "tcloud_enabled needs tcloud_api_token."
  }
}

variable "runner_ref" {
  type = object({
    kind = optional(string)
    uuid = optional(string)
  })
  nullable    = false
  description = "Runner of every definition this building block creates. `{}` uses the default shared runner."
}

variable "workspace" {
  type        = string
  nullable    = false
  description = "Workspace that owns the definitions this building block creates."
}

variable "hub" {
  type = object({
    git_ref   = optional(string, "main")
    bbd_draft = optional(bool, true)
  })
  const   = true
  default = { git_ref = "main", bbd_draft = true }

  description = <<-EOT
  `git_ref`: meshstack-hub reference the nested integrations are sourced from.
  `bbd_draft`: Keeps the definitions this building block creates in draft.
  EOT
}
