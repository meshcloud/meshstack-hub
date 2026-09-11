variable "storage_account_name" {
  type        = string
  nullable    = false
  description = "The name of the storage account. Must be unique across entire Azure Region, not just within a Subscription."
}

variable "location" {
  type        = string
  description = "The location/region where the storage account is created."
}

variable "account_tier" {
  type        = string
  default     = "Standard"
  description = "Performance tier of the storage account."
}

variable "account_replication_type" {
  type        = string
  default     = "LRS"
  nullable    = true
  description = "Replication strategy for the storage account. Only asked for while Account Tier is Standard; Premium storage always uses LRS, so this default is what a Premium deployment actually uses."
}

variable "blob_soft_delete_retention_days" {
  type        = number
  default     = 7
  description = "Number of days to retain deleted blobs. Optional: when omitted, this default applies."
}

variable "business_unit" {
  type = list(string)
  # meshStack sends a TAG input as a JSON array of strings; a tag with no value resolves to null.
  nullable    = true
  description = "Value of the workspace's BusinessUnit tag, read by meshStack rather than typed in by a user."
}

variable "network_rules" {
  type = object({
    default_action             = string
    bypass                     = optional(list(string), ["AzureServices"])
    ip_rules                   = optional(list(string), [])
    virtual_network_subnet_ids = optional(list(string), [])
  })
  description = "Network access restrictions for the storage account, filled in through a meshPanel form."
}
