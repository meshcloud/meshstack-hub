variable "postgresql_server_name" {
  type        = string
  nullable    = false
  description = "Name of the PostgreSQL Flexible Server. It is part of the server's DNS name, so it must be unique across Azure."
}

variable "resource_group_name" {
  type        = string
  nullable    = false
  description = "Name of the resource group the building block creates for the server."
}

variable "postgresql_version" {
  type        = string
  nullable    = false
  description = "PostgreSQL major version."
}

variable "sku_name" {
  type        = string
  nullable    = false
  description = "SKU of the server as tier and size, e.g. `B_Standard_B1ms` (Burstable) or `GP_Standard_D2ds_v5` (General Purpose)."
}

variable "storage_mb" {
  type        = number
  nullable    = false
  description = "Storage size in MB. Flexible Server accepts 32768, 65536, 131072 and larger powers of two. Storage can only grow."
}

variable "public_network_access_enabled" {
  type        = bool
  nullable    = false
  description = "Allow connections from the internet. Without firewall rules, no client can connect even then."
}

variable "subscription_id" {
  type        = string
  nullable    = false
  description = "The Azure subscription the server is created in."
}

variable "location" {
  type        = string
  nullable    = false
  description = "The Azure region the server is created in."
}

variable "administrator_login" {
  type        = string
  default     = "psqladmin"
  description = "Name of the administrator user."
}

variable "backup_retention_days" {
  type        = number
  default     = 7
  description = "Days to keep backups, from 7 to 35."
}

variable "geo_redundant_backup_enabled" {
  type        = bool
  default     = false
  description = "Store backups in the paired region too."
}

variable "auto_grow_enabled" {
  type        = bool
  default     = false
  description = "Grow the storage automatically when it is almost full."
}
