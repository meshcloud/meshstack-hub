# ── Backplane inputs (static, set once per building block definition) ──────────

variable "project_id" {
  type        = string
  nullable    = false
  description = "STACKIT project ID the PostgreSQL Flex instance is created in."
}

variable "service_account_email" {
  type        = string
  nullable    = true
  default     = null
  description = "Email of the STACKIT service account the provider authenticates as via workload identity federation. Leave unset when the caller supplies its own provider configuration."
}

variable "stackit_region" {
  type        = string
  nullable    = false
  default     = "eu01"
  description = "STACKIT region the instance is created in. Ignored when the caller supplies its own provider configuration."
}

# ── Instance shape ─────────────────────────────────────────────────────────────

variable "instance_name" {
  type        = string
  nullable    = false
  description = "Name of the PostgreSQL Flex instance."

  validation {
    condition     = can(regex("^[a-z0-9]([a-z0-9-]*[a-z0-9])?$", var.instance_name))
    error_message = "The instance name may contain lowercase letters, digits and hyphens, and must start and end with a letter or a digit."
  }
}

variable "flavor_cpu" {
  type        = number
  nullable    = false
  default     = 2
  description = "Number of vCPUs of the instance flavor. Together with `flavor_ram` and `replicas` this selects a STACKIT flavor. STACKIT offers 2/4, 4/8, 16/32, 2/16, 4/32, 16/128 and 8/16 as CPU/RAM pairs."
}

variable "flavor_ram" {
  type        = number
  nullable    = false
  default     = 4
  description = "Memory of the instance flavor in GiB. Must form a valid pair with `flavor_cpu`."
}

variable "replicas" {
  type        = number
  nullable    = false
  default     = 1
  description = "Number of nodes. 1 creates a single-node instance, 3 creates a replicated instance. STACKIT supports no other value."

  validation {
    condition     = contains([1, 3], var.replicas)
    error_message = "replicas must be either 1 (single node) or 3 (replicated)."
  }
}

variable "storage_class" {
  type        = string
  nullable    = false
  default     = "premium-perf2-stackit"
  description = "Storage performance class. STACKIT offers premium-perf2-stackit through premium-perf12-stackit, with higher numbers giving more IOPS and throughput."
}

variable "storage_size" {
  type        = number
  nullable    = false
  default     = 20
  description = "Storage size of the instance in GB."

  validation {
    condition     = var.storage_size >= 5
    error_message = "storage_size must be at least 5 GB."
  }
}

variable "postgres_version" {
  type        = string
  nullable    = false
  default     = "17"
  description = "PostgreSQL major version. Version 14 reaches end of life on 12 November 2026, so pick 16 or newer."

  validation {
    condition     = can(regex("^(1[6-9]|[2-9][0-9])$", var.postgres_version))
    error_message = "postgres_version must be 16 or newer. Versions 13, 14 and 15 are end of life or close to it."
  }
}

# ── Backup ─────────────────────────────────────────────────────────────────────

variable "backup_schedule" {
  type        = string
  nullable    = false
  default     = "0 2 * * *"
  description = "Cron expression that decides when STACKIT takes the daily backup. Minute and hour must be numeric, for example '0 2 * * *' for 02:00 UTC."
}

variable "retention_days" {
  type        = number
  nullable    = false
  default     = 32
  description = "Number of days STACKIT keeps backups. STACKIT accepts 32 to 90."

  validation {
    condition     = var.retention_days >= 32 && var.retention_days <= 90
    error_message = "retention_days must be between 32 and 90."
  }
}

# ── Network access ─────────────────────────────────────────────────────────────

variable "acl" {
  type     = list(string)
  nullable = false
  default  = ["193.148.160.0/19", "45.129.40.0/21", "45.135.244.0/22"]

  description = <<-EOT
  Source IPv4 CIDR ranges allowed to open a connection to the instance. The default is the set of
  STACKIT service ranges that STACKIT documents as the predefined ACL for its data services, so
  other STACKIT services can reach the instance.

  An SKE cluster leaves its network through a router that applies NAT, so the instance sees the
  cluster's public egress IP and not a private address. Add that egress IP as a /32 entry when the
  cluster's range is not already covered here. Never add 0.0.0.0/0 — STACKIT documents that as
  something to avoid, because it opens the instance to every address on the internet.
  EOT

  validation {
    condition     = length(var.acl) > 0
    error_message = "acl must contain at least one CIDR range, otherwise nothing can reach the instance."
  }

  validation {
    condition     = alltrue([for cidr in var.acl : can(cidrnetmask(cidr))])
    error_message = "Every entry of acl must be a valid IPv4 CIDR range, for example 45.129.40.0/21."
  }

  validation {
    condition     = !contains(var.acl, "0.0.0.0/0")
    error_message = "acl must not contain 0.0.0.0/0. STACKIT documents that entry as one to avoid, because it lets every address on the internet reach the instance. List the ranges your clients actually use."
  }
}

variable "allow_stackit_public_ip_ranges" {
  type        = bool
  nullable    = false
  default     = false
  description = "Add every public IP range STACKIT publishes to the ACL, on top of `acl`. This reads the `stackit_public_ip_ranges` data source, which is the machine-readable list STACKIT keeps current. Turn it on when the hardcoded default in `acl` goes stale, at the cost of a much wider allowlist."
}

variable "network_access_scope" {
  type        = string
  nullable    = true
  default     = null
  description = "Network access scope of the instance, either `PUBLIC` or `SNA`. Leave unset to get the STACKIT default. `SNA` is in private preview and STACKIT rejects the request when the project is not enabled for it."

  validation {
    condition     = var.network_access_scope == null ? true : contains(["PUBLIC", "SNA"], var.network_access_scope)
    error_message = "network_access_scope must be either PUBLIC or SNA."
  }
}

# ── Database and user ──────────────────────────────────────────────────────────

variable "database_name" {
  type        = string
  nullable    = false
  default     = "app"
  description = "Name of the database created on the instance."

  validation {
    condition     = can(regex("^[a-z_][a-z0-9_]*$", var.database_name))
    error_message = "The database name may contain lowercase letters, digits and underscores, and must not start with a digit."
  }
}

variable "database_username" {
  type        = string
  nullable    = false
  default     = "app"
  description = "Name of the database user that owns the database. STACKIT generates the password and this module returns it as a sensitive output."

  validation {
    condition     = can(regex("^[a-z_][a-z0-9_]*$", var.database_username))
    error_message = "The username may contain lowercase letters, digits and underscores, and must not start with a digit."
  }
}

variable "database_user_roles" {
  type        = list(string)
  nullable    = false
  default     = ["login", "createdb"]
  description = "Roles granted to the database user. STACKIT supports `login` and `createdb`."

  validation {
    condition     = alltrue([for role in var.database_user_roles : contains(["login", "createdb"], role)])
    error_message = "database_user_roles may only contain 'login' and 'createdb'."
  }
}
