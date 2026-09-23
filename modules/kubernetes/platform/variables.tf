variable "kubeconfig" {
  type        = string
  sensitive   = true
  description = "Raw kubeconfig (YAML) of the target cluster, from a preceding building block so it is known at plan time."
}

variable "service_account_namespace" {
  type        = string
  nullable    = false
  description = "Namespace that holds the replicator and metering service accounts."
}

variable "metering_enabled" {
  type        = bool
  nullable    = false
  description = "Create the metering service account; `metering_token` is null without it."
}

variable "replicator_additional_rules" {
  type = list(object({
    api_groups        = list(string)
    resources         = list(string)
    verbs             = list(string)
    resource_names    = optional(list(string))
    non_resource_urls = optional(list(string))
  }))
  nullable    = false
  description = "Extra RBAC rules added to the replicator cluster role."
}

variable "metering_additional_rules" {
  type = list(object({
    api_groups        = list(string)
    resources         = list(string)
    verbs             = list(string)
    resource_names    = optional(list(string))
    non_resource_urls = optional(list(string))
  }))
  nullable    = false
  description = "Extra RBAC rules added to the metering cluster role."
}
