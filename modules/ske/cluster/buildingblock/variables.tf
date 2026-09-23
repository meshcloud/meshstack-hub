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
  description = "STACKIT region the cluster and its node pool are placed in."
}

variable "cluster_name" {
  type        = string
  description = "Name of the SKE cluster."

  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9-]{0,9}[a-z0-9]$", var.cluster_name))
    error_message = "cluster_name must be 2-11 characters, lowercase alphanumeric or dashes, and not start or end with a dash."
  }
}

variable "kubernetes_version_min" {
  type        = string
  description = "Minimum Kubernetes minor version to run. Null lets STACKIT pick the current default."
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
  nullable    = false
  description = "Single node pool the cluster starts with."
}

variable "maintenance" {
  type = object({
    enable_kubernetes_version_updates    = optional(bool, true)
    enable_machine_image_version_updates = optional(bool, true)
    start                                = optional(string, "01:00:00Z")
    end                                  = optional(string, "02:00:00Z")
  })
  nullable    = false
  description = "SKE maintenance window."
}
