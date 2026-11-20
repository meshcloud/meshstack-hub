variable "project_id" {
  type        = string
  nullable    = false
  description = "STACKIT project ID of the instance."
}

variable "instance_id" {
  type        = string
  nullable    = false
  description = "ID of the PostgreSQL Flex instance the database is created on."

  validation {
    condition     = can(regex("^[0-9a-f]{8}(-[0-9a-f]{4}){3}-[0-9a-f]{12}$", var.instance_id))
    error_message = "instance_id is the UUID of a PostgreSQL Flex instance."
  }
}

variable "database_name" {
  type        = string
  nullable    = false
  description = "Name of the database. Unique on the instance."

  validation {
    condition     = can(regex("^[a-z_][a-z0-9_]{0,62}$", var.database_name))
    error_message = "The database name is at most 63 lowercase letters, digits and underscores and does not start with a digit."
  }
}

variable "username" {
  type        = string
  nullable    = false
  description = "Name of the database user that owns the database. Unique on the instance."

  validation {
    condition     = can(regex("^[a-z_][a-z0-9_]{0,62}$", var.username))
    error_message = "The username is at most 63 lowercase letters, digits and underscores and does not start with a digit."
  }
}
