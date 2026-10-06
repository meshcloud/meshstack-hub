variable "service_account_namespace" {
  type        = string
  nullable    = false
  description = "Namespace that holds the replicator and metering service accounts."
}

variable "metering_enabled" {
  type        = bool
  nullable    = false
  description = "Create the metering service account; `metering_token` is empty without it."
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

variable "output_to_vault" {
  type = object({
    address  = string
    mount    = string
    username = string
    password = string
    path     = string
  })
  default     = null
  sensitive   = true
  description = "Vault KV v2 secret this building block writes its secrets to instead of returning them as outputs: the server `address`, the engine `mount`, a userpass `username` and `password`, and the secret `path`. Null returns them as outputs."
}
