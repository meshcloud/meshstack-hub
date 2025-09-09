variable "storage_account_name" {
  type        = string
  nullable    = false
  description = "The name of the key vault. Must be unique across entire Azure Region, not just within a Subscription."
}

variable "storage_account_resource_group_name" {
  type        = string
  nullable    = false
  description = "The name of the resource group containing the key vault."
}

variable "location" {
  type        = string
  description = "The location/region where the key vault is created."
}