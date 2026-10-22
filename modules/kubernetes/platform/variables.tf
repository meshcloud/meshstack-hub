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

variable "token_generation" {
  type        = string
  nullable    = false
  description = "Month `YYYY-MM` of the current replicator and metering tokens."

  validation {
    condition     = can(regex("^[0-9]{4}-(0[1-9]|1[0-2])$", var.token_generation))
    error_message = "token_generation must be a month in the form YYYY-MM."
  }
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
  description = "Vault KV v2 userpass login that writes the tokens to `<path_prefix>kubernetes/platform`. Null returns them as outputs."
}

variable "imports" {
  type        = object({})
  default     = null
  description = "Set to `{}` to take over the namespace and the replicator and metering identities of an earlier meshPlatform registration."
}

variable "release_on_destroy" {
  type        = bool
  nullable    = false
  default     = false
  description = "Leave the namespace and the objects in it in place on destroy. Cannot change once they are managed."
}
