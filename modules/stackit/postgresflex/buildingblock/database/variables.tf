# Every variable here also exists on the calling root, which passes each one straight through, so
# the two entry points take the same inputs and reject the same values. The root has no variable
# of its own beyond `service_account_email`, which only configures its provider.

# ── Project and region ─────────────────────────────────────────────────────────

variable "project_id" {
  type        = string
  nullable    = false
  description = "STACKIT project ID the PostgreSQL Flex instance is created in."
}

variable "stackit_region" {
  type        = string
  nullable    = false
  default     = "eu01"
  description = "STACKIT region the instance lives in. Every resource in this module carries it, so it stays an input even when the caller configures the provider with a region of its own."
}

# ── Create an instance, or use an existing one ─────────────────────────────────

variable "existing_instance_id" {
  type        = string
  nullable    = true
  default     = null
  description = <<-EOT
  UUID of a PostgreSQL Flex instance that already exists. Leave it unset and the module creates the
  instance, the database and the owner user as one unit. Set it and the module creates only the
  database and the owner user inside that instance, so several tenants can share one instance and
  stay separated by database name.

  Database-only mode skips the instance resource, so every input describing the instance shape has
  no effect: `instance_name`, `flavor_cpu`, `flavor_ram`, `replicas`, `storage_class`,
  `storage_size`, `postgres_version`, `backup_schedule`, `retention_days`, `acl`,
  `allow_stackit_public_ip_ranges` and `network_access_scope`. `project_id` must name the project
  the shared instance lives in and `stackit_region` its region.
  EOT

  # A caller that builds this value with an expression such as `try(...)` or `lookup(...)` easily
  # ends up passing an empty string. That would select database-only mode and then send an empty
  # instance ID to the API, so the module rejects it here instead of failing on a request the
  # message of which explains nothing.
  validation {
    condition     = var.existing_instance_id == null ? true : trimspace(var.existing_instance_id) != ""
    error_message = "existing_instance_id must be null or a UUID. An empty string selects database-only mode and then names no instance."
  }

  validation {
    condition     = var.existing_instance_id == null ? true : can(regex("^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$", var.existing_instance_id))
    error_message = "existing_instance_id must be a UUID, for example 3f2504e0-4f89-11d3-9a0c-0305e82c3301."
  }
}

# ── Instance shape ─────────────────────────────────────────────────────────────

variable "instance_name" {
  type        = string
  nullable    = true
  default     = null
  description = "Name of the PostgreSQL Flex instance the module creates. Leave it unset in database-only mode, where `existing_instance_id` selects the instance instead."

  validation {
    condition     = var.instance_name == null ? true : can(regex("^[a-z0-9]([a-z0-9-]*[a-z0-9])?$", var.instance_name))
    error_message = "The instance name may contain lowercase letters, digits and hyphens, and must start and end with a letter or a digit."
  }

  validation {
    condition     = (var.instance_name == null) != (var.existing_instance_id == null)
    error_message = "Set exactly one of instance_name and existing_instance_id. Set instance_name to create a new instance together with the database and the user, or set existing_instance_id to create only the database and the user inside an instance that already exists."
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
  description = "Memory of the instance flavor in GiB. Must form a valid pair with `flavor_cpu`. Memory also decides `max_connections`: 4 GiB gives 95, 8 GiB gives 195, 16 GiB gives 385, 32 GiB gives 785 and 128 GiB gives 3170, of which STACKIT reserves 15 for itself. The vCPU count has no effect on the limit."
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
  description = "Roles granted to the database user. STACKIT supports `login` and `createdb`. Applications that run their migrations with `prisma migrate deploy`, Langfuse among them, need only `login`."

  validation {
    condition     = alltrue([for role in var.database_user_roles : contains(["login", "createdb"], role)])
    error_message = "database_user_roles may only contain 'login' and 'createdb'."
  }
}
