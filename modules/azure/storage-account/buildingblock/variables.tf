variable "storage_account_name" {
  type        = string
  nullable    = false
  description = "The name of the storage account. Must be unique across entire Azure Region, not just within a Subscription."
}

variable "location" {
  type        = string
  description = "The location/region where the storage account is created."
}

variable "blob_soft_delete_retention_days" {
  type        = number
  default     = 7
  description = "Number of days to retain deleted blobs. Optional: when omitted, this default applies."
}

variable "tag_name" {
  type        = string
  default     = null
  description = "Name of the workspace tag applied to the storage account, also used as the Azure tag key. Set from outside via the integration's workspace_tag_to_copy; null copies no tag."
}

variable "tag_value" {
  type        = list(string)
  default     = null
  description = "Value of the workspace tag named by tag_name, resolved by meshStack. Null when tag_name is unset or the workspace has no value for it."
}

variable "restrict_network_access" {
  type        = bool
  default     = false
  description = "Whether to restrict network access to the storage account. When false, the storage account allows traffic from any network and network_rules is ignored."
}

variable "network_rules" {
  # default_action isn't part of this input: it's implied by restrict_network_access (Deny when
  # set, Allow otherwise).
  type = object({
    bypass                     = optional(list(string), ["AzureServices"])
    ip_rules                   = optional(list(string), [])
    virtual_network_subnet_ids = optional(list(string), [])
  })
  default     = {}
  description = "Network access restrictions applied when restrict_network_access is true, filled in through a meshPanel form."
}
