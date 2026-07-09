variable "postgresql_server_name" {
  description = "Name prefix for the PostgreSQL Flexible Server. A random 5-character suffix is appended to ensure global uniqueness. Only lowercase letters, numbers and hyphens are allowed."
  type        = string
  nullable    = false
  validation {
    condition     = can(regex("^[a-z0-9-]{3,57}$", var.postgresql_server_name))
    error_message = "Only lowercase letters, numbers and hyphens are allowed, between 3 and 57 characters (a 6-character suffix is appended, keeping the final name within Azure's 63-character limit)."
  }
}

variable "location" {
  description = "Azure region where the PostgreSQL Flexible Server is created."
  type        = string
  default     = "germanywestcentral"
}

variable "administrator_login" {
  description = "Administrator username for the PostgreSQL Flexible Server."
  type        = string
  default     = "psqladmin"
}

variable "sku_name" {
  description = "The SKU name for the PostgreSQL Flexible Server (tier + size, e.g. B_Standard_B1ms, GP_Standard_D2s_v3)."
  type        = string
  default     = "B_Standard_B1ms"
}

variable "postgresql_version" {
  description = "PostgreSQL major version."
  type        = string
  default     = "16"
}

variable "storage_mb" {
  description = "Storage size in MB. Must be one of the sizes supported by Azure Database for PostgreSQL Flexible Server (e.g. 32768, 65536, 131072)."
  type        = number
  default     = 32768
}

variable "backup_retention_days" {
  description = "Backup retention in days (7-35)."
  type        = number
  default     = 7
}

variable "geo_redundant_backup_enabled" {
  description = "Enable geo-redundant backups."
  type        = bool
  default     = false
}

variable "public_network_access_enabled" {
  description = "Enable public network access. Disabling requires VNet integration (delegated subnet), which is out of scope for this building block."
  type        = bool
  default     = true
}
