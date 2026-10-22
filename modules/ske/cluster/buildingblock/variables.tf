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

variable "output_to_vault" {
  type = object({
    address     = string
    mount       = string
    username    = string
    password    = string
    path_prefix = optional(string, "")
  })
  nullable    = false
  sensitive   = true
  description = "Vault KV v2 login this building block writes the platform admin kubeconfig with: the server `address`, the engine `mount`, a userpass `username` and `password`, and an optional `path_prefix`. The secret is `<path_prefix>ske/cluster`, with the key `kubeconfig`."
}

variable "admin_token_generation" {
  type        = string
  nullable    = false
  description = "Month `YYYY-MM` of the platform admin token the kubeconfig carries. The token of the month before stays valid, older ones are deleted."

  validation {
    condition     = can(regex("^[0-9]{4}-(0[1-9]|1[0-2])$", var.admin_token_generation))
    error_message = "admin_token_generation must be a month in the form YYYY-MM."
  }
}

variable "imports" {
  type        = object({})
  default     = null
  description = "Set to `{}` to take over the existing SKE cluster named `cluster_name` instead of creating one. Null creates a new cluster."
}

variable "release_on_destroy" {
  type        = bool
  nullable    = false
  default     = false
  description = "Leave the cluster in place when this building block is destroyed. Cannot change once the cluster is managed."
}
