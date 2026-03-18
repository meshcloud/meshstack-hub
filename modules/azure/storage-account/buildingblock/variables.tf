variable "storage_account_name" {
  type        = string
  nullable    = false
  description = "The name of the storage account. Must be unique across entire Azure Region, not just within a Subscription."
}

variable "location" {
  type        = string
  description = "The location/region where the storage account is created."
}