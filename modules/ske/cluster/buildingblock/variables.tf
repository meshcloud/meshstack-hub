variable "stackit_project_id" {
  type        = string
  description = "STACKIT project UUID the SKE cluster is created in."

  validation {
    condition     = can(regex("^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$", var.stackit_project_id))
    error_message = "stackit_project_id must be a valid UUID."
  }
}

variable "stackit_region" {
  type        = string
  default     = "eu01"
  description = "STACKIT region the cluster and its node pool are placed in."
}

variable "cluster_name" {
  type        = string
  description = "Name of the SKE cluster. STACKIT caps SKE cluster names at 11 characters (lowercase alphanumeric and dashes)."

  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9-]{0,9}[a-z0-9]$", var.cluster_name))
    error_message = "cluster_name must be 2-11 characters, lowercase alphanumeric or dashes, and not start or end with a dash."
  }
}

variable "kubernetes_version_min" {
  type        = string
  default     = null
  description = "Minimum Kubernetes minor version to run (e.g. `1.31`). Null lets STACKIT pick the current default; maintenance keeps it patched upward."
}

variable "node_pool" {
  type = object({
    name               = optional(string, "pool-1")
    machine_type       = optional(string, "g2i.2")
    minimum            = optional(number, 1)
    maximum            = optional(number, 3)
    availability_zones = optional(list(string), ["eu01-1"])
    max_surge          = optional(number, 1)
  })
  default     = {}
  description = "Single node pool the cluster starts with. Defaults to a small general-purpose pool (`g2i.2`, 1-3 nodes) in `eu01-1`."
}

variable "maintenance" {
  type = object({
    enable_kubernetes_version_updates    = optional(bool, true)
    enable_machine_image_version_updates = optional(bool, true)
    start                                = optional(string, "01:00:00Z")
    end                                  = optional(string, "02:00:00Z")
  })
  default     = {}
  description = "SKE maintenance window. Defaults to nightly automatic Kubernetes and machine-image updates between 01:00 and 02:00 UTC."
}
