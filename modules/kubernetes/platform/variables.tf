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
    address     = string
    mount       = string
    username    = string
    password    = string
    path_prefix = optional(string, "")
  })
  default     = null
  sensitive   = true
  description = "Vault KV v2 login this building block writes its secret with: the server `address`, the engine `mount`, a userpass `username` and `password`, and an optional `path_prefix`. The secret is `<path_prefix>kubernetes/platform`, with the keys `replicator-token` and, when metering is enabled, `metering-token`. Null returns them as outputs."
}

variable "imports" {
  type        = object({})
  default     = null
  description = "Set to `{}` to take over the existing namespace `service_account_namespace` and the replicator and metering ServiceAccounts, token Secrets, ClusterRoles and ClusterRoleBindings of their fixed names, for example those of an earlier meshPlatform registration. Null creates them."
}

variable "release_on_destroy" {
  type        = bool
  nullable    = false
  default     = false
  description = "Leave the namespace and the objects in it in place when this building block is destroyed. Cannot change once they are managed."
}
