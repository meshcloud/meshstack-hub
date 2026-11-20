variable "project_id" {
  type        = string
  nullable    = false
  description = "STACKIT project ID of the instance."
}

variable "existing_instance_id" {
  type        = string
  default     = null
  description = "ID of a PostgreSQL Flex instance in `project_id` to create only the database and its user on. Null creates an instance; `instance` is then required."

  validation {
    condition     = var.existing_instance_id == null || can(regex("^[0-9a-f]{8}(-[0-9a-f]{4}){3}-[0-9a-f]{12}$", var.existing_instance_id))
    error_message = "existing_instance_id is the UUID of a PostgreSQL Flex instance."
  }
}

variable "instance" {
  type = object({
    name                  = string
    flavor                = string
    replicas              = number
    storage_class         = string
    storage_size          = number
    postgres_version      = string
    backup_schedule       = string
    backup_retention_days = number
    acl                   = list(string)
  })
  default     = null
  description = "Settings of the instance to create. Ignored with `existing_instance_id`."

  validation {
    condition     = (var.instance == null) != (var.existing_instance_id == null)
    error_message = "Set either instance, to create an instance, or existing_instance_id, to use one."
  }

  validation {
    condition     = var.instance == null || can(regex("^[a-z]([-a-z0-9]{0,61}[a-z0-9])?$", var.instance.name))
    error_message = "The instance name is at most 63 lowercase letters, digits and hyphens, starts with a letter and does not end with a hyphen."
  }

  validation {
    condition     = var.instance == null || contains(["2.4", "2.16", "4.8", "4.32", "8.16", "8.32", "16.32", "16.64", "16.128", "30.240"], var.instance.flavor)
    error_message = "STACKIT offers the flavors 2.4, 2.16, 4.8, 4.32, 8.16, 8.32, 16.32, 16.64, 16.128 and 30.240."
  }

  validation {
    condition     = var.instance == null || contains([1, 3], var.instance.replicas)
    error_message = "STACKIT supports 1 node or 3 nodes."
  }

  validation {
    condition     = var.instance == null || can(regex("^premium-perf(2|4|6|8|10|12)-stackit$", var.instance.storage_class))
    error_message = "The storage class is premium-perf<N>-stackit with N one of 2, 4, 6, 8, 10, 12."
  }

  validation {
    condition     = var.instance == null || (var.instance.storage_size >= 5 && var.instance.storage_size <= (var.instance.flavor == "30.240" && var.instance.replicas == 1 ? 2000 : 4000))
    error_message = "The storage size is 5 to 4000 GB, and at most 2000 GB for a single node of flavor 30.240."
  }

  validation {
    condition     = var.instance == null || contains(["15", "16", "17", "18"], var.instance.postgres_version)
    error_message = "STACKIT offers PostgreSQL 15, 16, 17 and 18 (beta); 14 is deprecated."
  }

  validation {
    condition     = var.instance == null || can(regex("^([0-9]|[1-5][0-9]) ([0-9]|1[0-9]|2[0-3]) \\S+ \\S+ \\S+$", var.instance.backup_schedule))
    error_message = "The backup schedule is a five-field cron expression with a numeric minute (0-59) and hour (0-23)."
  }

  validation {
    condition     = var.instance == null || (var.instance.backup_retention_days >= 32 && var.instance.backup_retention_days <= 90)
    error_message = "STACKIT keeps backups for 32 to 90 days."
  }

  validation {
    condition     = var.instance == null || (length(var.instance.acl) > 0 && alltrue([for cidr in var.instance.acl : can(cidrnetmask(cidr))]))
    error_message = "The ACL needs at least one entry, and every entry is an IPv4 CIDR range such as 203.0.113.7/32."
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
