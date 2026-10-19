variable "project_id" {
  type        = string
  nullable    = false
  description = "ID of the T Cloud Public project the database is created in."
}

variable "region" {
  type        = string
  default     = "eu-de"
  nullable    = false
  description = "T Cloud Public region of the project."
}

variable "network_name" {
  type        = string
  default     = "app"
  nullable    = false
  description = "Name of the VPC and of its subnet the database is placed in, as the T Cloud Public Network building block created them."
}

variable "name" {
  type        = string
  nullable    = false
  description = "Name of the database instance, unique within the project."

  validation {
    condition     = can(regex("^[A-Za-z][A-Za-z0-9_-]{3,63}$", var.name))
    error_message = "name must be 4 to 64 characters, start with a letter, and contain only letters, digits, hyphens and underscores."
  }
}

variable "db_type" {
  type        = string
  default     = "PostgreSQL"
  nullable    = false
  description = "Database engine: MySQL, PostgreSQL or SQLServer."

  validation {
    condition     = contains(["MySQL", "PostgreSQL", "SQLServer"], var.db_type)
    error_message = "db_type must be MySQL, PostgreSQL or SQLServer."
  }
}

variable "db_version" {
  type        = string
  default     = null
  description = "Engine version, e.g. `16` for PostgreSQL, `8.0` for MySQL or `2022_SE` for SQL Server. Null picks the newest version the region offers, for SQL Server its Standard Edition."
}

variable "size" {
  type        = string
  default     = "small"
  nullable    = false
  description = "Compute size of each database node: small (2 vCPUs, 4 GB), medium (4 vCPUs, 8 GB) or large (8 vCPUs, 16 GB)."

  validation {
    condition     = contains(["small", "medium", "large"], var.size)
    error_message = "size must be small, medium or large."
  }
}

variable "storage_size" {
  type        = number
  default     = 100
  nullable    = false
  description = "Storage of the database in GB, between 40 and 4000."

  validation {
    condition     = var.storage_size >= 40 && var.storage_size <= 4000
    error_message = "storage_size must be between 40 and 4000 GB."
  }
}

variable "high_availability" {
  type        = bool
  default     = false
  nullable    = false
  description = "Run a primary and a standby node in two availability zones instead of a single node."
}
