variable "kubeconfig" {
  type        = string
  sensitive   = true
  description = "Raw kubeconfig (YAML) of the cluster the identities are created in — for example the `kubeconfig` output of the STACKIT SKE Cluster building block. The kubernetes provider is configured from it, so it must be a concrete value at plan time (i.e. supplied by a preceding building block, not created in this run)."
}

variable "service_account_namespace" {
  type        = string
  nullable    = false
  default     = "meshcloud"
  description = "Namespace that holds the replicator and metering service accounts."
}

variable "metering_enabled" {
  type        = bool
  nullable    = false
  default     = true
  description = "Create the metering service account. Turn this off when meshStack should not collect usage data from the cluster; `metering_token` is then null."
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
  default     = []
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
  default     = []
  description = "Extra RBAC rules added to the metering cluster role."
}
