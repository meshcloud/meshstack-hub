variable "aks_cluster_name" {
  type        = string
  nullable    = false
  description = "Name of the AKS cluster the namespace is created in."
}

variable "aks_resource_group_name" {
  type        = string
  nullable    = false
  description = "Resource group of the AKS cluster."
}

variable "workspace_identifier" {
  type        = string
  nullable    = false
  description = "Identifier of the meshStack workspace that owns the namespace. Recorded as a label."
}

variable "namespace_name" {
  type        = string
  nullable    = false
  description = "Name of the Kubernetes namespace to create."

  validation {
    condition     = can(regex("^[a-z0-9]([-a-z0-9]{0,61}[a-z0-9])?$", var.namespace_name))
    error_message = "Must be a valid DNS label: lowercase alphanumerics and dashes, at most 63 characters, starting and ending alphanumeric."
  }
}

variable "admin_group_object_ids" {
  type        = list(string)
  default     = []
  description = "Entra group object IDs granted the `admin` cluster role inside the namespace."
}

variable "edit_group_object_ids" {
  type        = list(string)
  default     = []
  description = "Entra group object IDs granted the `edit` cluster role inside the namespace."
}

variable "view_group_object_ids" {
  type        = list(string)
  default     = []
  description = "Entra group object IDs granted the `view` cluster role inside the namespace."
}

variable "resource_quota" {
  type = object({
    requests_cpu    = optional(string, "2")
    requests_memory = optional(string, "4Gi")
    limits_cpu      = optional(string, "4")
    limits_memory   = optional(string, "8Gi")
    pods            = optional(string, "50")
  })
  default     = {}
  description = "ResourceQuota applied to the namespace."
}

variable "default_container_limits" {
  type = object({
    cpu_request    = optional(string, "100m")
    memory_request = optional(string, "128Mi")
    cpu_limit      = optional(string, "500m")
    memory_limit   = optional(string, "512Mi")
  })
  default     = {}
  description = "LimitRange defaults for containers that declare no requests or limits of their own."
}

variable "oidc_token_file_path" {
  type        = string
  default     = "/var/run/secrets/workload-identity/azure/token"
  description = "File the building block runner writes its federated OIDC token to."
}
