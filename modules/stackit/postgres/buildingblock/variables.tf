variable "instance_name" {
  type        = string
  default     = null
  description = "Name of the PostgreSQL Flex instance. This and the other instance settings are ignored with `existing_instance_id`."
}

variable "flavor" {
  type        = string
  default     = null
  description = "Size of each node as `<vCPU>.<RAM in GB>`, for example `2.4`."
}

variable "replicas" {
  type        = number
  default     = null
  description = "Number of nodes: 1 for a single node, 3 for a highly available replica set."
}

variable "storage_class" {
  type        = string
  default     = null
  description = "Storage performance class, from `premium-perf2-stackit` (1000 IOPS) to `premium-perf12-stackit` (20000 IOPS). Cannot change after creation."
}

variable "storage_size" {
  type        = number
  default     = null
  description = "Storage size in GB. Can grow, never shrink."
}

variable "postgres_version" {
  type        = string
  default     = null
  description = "PostgreSQL major version."
}

variable "backup_schedule" {
  type        = string
  default     = null
  description = "Cron expression in UTC for the backup, with numeric minute and hour, for example `0 2 * * *`."
}

variable "backup_retention_days" {
  type        = number
  default     = null
  description = "Number of days STACKIT keeps backups."
}

variable "acl" {
  type        = list(string)
  default     = null
  description = "IPv4 CIDR ranges allowed to connect. The instance has a public endpoint and accepts no other source. Workloads on an SKE cluster connect from the cluster's egress address."
}

variable "database_name" {
  type        = string
  default     = null
  description = "Name of the database. Null derives it from `workspace_identifier` and `project_identifier`."

  validation {
    condition     = var.database_name != null || (var.workspace_identifier != null && var.project_identifier != null)
    error_message = "Set database_name, or workspace_identifier and project_identifier to derive it."
  }
}

variable "username" {
  type        = string
  default     = null
  description = "Name of the database user that owns the database. Null derives it like `database_name`."
}

variable "output_to_vault" {
  type = object({
    address     = string
    mount       = string
    username    = string
    path_prefix = optional(string, "")
  })
  default     = null
  description = "Vault KV v2 userpass login that writes the connection data, password included, to `<path_prefix>stackit/postgres/<instance id>`, with `existing_instance_id` to `<path_prefix>stackit/postgres/<instance id>/<database>`. Null hands out no password."
}

variable "output_to_vault_password" {
  type        = string
  default     = null
  sensitive   = true
  ephemeral   = true
  description = "Password of the `output_to_vault` user."
}

variable "existing_instance_id" {
  type        = string
  default     = null
  description = "ID of a PostgreSQL Flex instance in `project_id`. The building block then creates only a database and its owner user on it. Null creates an instance."
}

variable "project_id" {
  type        = string
  nullable    = false
  description = "STACKIT project ID the instance is created in."
}

variable "workspace_identifier" {
  type        = string
  default     = null
  description = "meshStack workspace of the building block, for the derived database name."
}

variable "project_identifier" {
  type        = string
  default     = null
  description = "meshStack project of the building block, for the derived database name."
}
