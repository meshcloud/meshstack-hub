variable "instance_name" {
  type        = string
  default     = null
  description = "Name of the PostgreSQL Flex instance. This and the other instance settings are required without `existing_instance_id` and ignored with it."

  validation {
    condition     = var.instance_name == null || can(regex("^[a-z]([-a-z0-9]{0,61}[a-z0-9])?$", var.instance_name))
    error_message = "The instance name is at most 63 lowercase letters, digits and hyphens, starts with a letter and does not end with a hyphen."
  }
}

variable "flavor" {
  type        = string
  default     = null
  description = "Size of each node as `<vCPU>.<RAM in GB>`, for example `2.4`."

  validation {
    condition     = var.flavor == null || contains(["2.4", "2.16", "4.8", "4.32", "8.16", "8.32", "16.32", "16.64", "16.128", "30.240"], var.flavor)
    error_message = "STACKIT offers the flavors 2.4, 2.16, 4.8, 4.32, 8.16, 8.32, 16.32, 16.64, 16.128 and 30.240."
  }
}

variable "replicas" {
  type        = number
  default     = null
  description = "Number of nodes: 1 for a single node, 3 for a highly available replica set."

  validation {
    condition     = var.replicas == null || contains([1, 3], var.replicas)
    error_message = "STACKIT supports 1 node or 3 nodes."
  }
}

variable "storage_class" {
  type        = string
  default     = null
  description = "Storage performance class, from `premium-perf2-stackit` (1000 IOPS) to `premium-perf12-stackit` (20000 IOPS). Cannot change after creation."

  validation {
    condition     = var.storage_class == null || can(regex("^premium-perf(2|4|6|8|10|12)-stackit$", var.storage_class))
    error_message = "The storage class is premium-perf<N>-stackit with N one of 2, 4, 6, 8, 10, 12."
  }
}

variable "storage_size" {
  type        = number
  default     = null
  description = "Storage size in GB. Can grow, never shrink."

  validation {
    condition     = var.storage_size == null || (var.storage_size >= 5 && var.storage_size <= (var.flavor == "30.240" && var.replicas == 1 ? 2000 : 4000))
    error_message = "The storage size is 5 to 4000 GB, and at most 2000 GB for a single node of flavor 30.240."
  }
}

variable "postgres_version" {
  type        = string
  default     = null
  description = "PostgreSQL major version."

  validation {
    condition     = var.postgres_version == null || contains(["15", "16", "17", "18"], var.postgres_version)
    error_message = "STACKIT offers PostgreSQL 15, 16, 17 and 18 (beta); 14 is deprecated."
  }
}

variable "backup_schedule" {
  type        = string
  default     = null
  description = "Cron expression in UTC for the backup, with numeric minute and hour, for example `0 2 * * *`."

  validation {
    condition     = var.backup_schedule == null || can(regex("^([0-9]|[1-5][0-9]) ([0-9]|1[0-9]|2[0-3]) \\S+ \\S+ \\S+$", var.backup_schedule))
    error_message = "The backup schedule is a five-field cron expression with a numeric minute (0-59) and hour (0-23)."
  }
}

variable "backup_retention_days" {
  type        = number
  default     = null
  description = "Number of days STACKIT keeps backups."

  validation {
    condition     = var.backup_retention_days == null || (var.backup_retention_days >= 32 && var.backup_retention_days <= 90)
    error_message = "STACKIT keeps backups for 32 to 90 days."
  }
}

variable "acl" {
  type        = list(string)
  default     = null
  description = "IPv4 CIDR ranges allowed to connect. The instance has a public endpoint and accepts no other source. Workloads on an SKE cluster connect from the cluster's egress address."

  validation {
    condition     = var.acl == null || (length(var.acl) > 0 && alltrue([for cidr in var.acl : can(cidrnetmask(cidr))]))
    error_message = "The ACL needs at least one entry, and every entry is an IPv4 CIDR range such as 203.0.113.7/32."
  }
}

variable "existing_instance_id" {
  type        = string
  default     = null
  description = "ID of a PostgreSQL Flex instance in `project_id`. The building block then creates a database and its owner user on it. Null creates an instance and nothing else."

  validation {
    condition     = var.existing_instance_id != null || !contains([for setting in [var.instance_name, var.flavor, var.replicas, var.storage_class, var.storage_size, var.postgres_version, var.backup_schedule, var.backup_retention_days, var.acl] : setting == null], true)
    error_message = "Without existing_instance_id, set every instance setting."
  }

  validation {
    condition     = var.existing_instance_id == null || (var.workspace_identifier != null && var.project_identifier != null)
    error_message = "With existing_instance_id, set workspace_identifier and project_identifier, which name the database."
  }
}

variable "project_id" {
  type        = string
  nullable    = false
  description = "STACKIT project ID of the instance."
}

variable "workspace_identifier" {
  type        = string
  default     = null
  description = "meshStack workspace of the building block. Database and user are named `<workspace>_<project>`."
}

variable "project_identifier" {
  type        = string
  default     = null
  description = "meshStack project of the building block. Database and user are named `<workspace>_<project>`."
}
