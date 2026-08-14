variable "stackit_project_id" {
  type        = string
  nullable    = false
  description = "STACKIT project UUID that holds the SKE cluster."
}

variable "cluster_name" {
  type        = string
  nullable    = false
  description = "Name of the SKE cluster. STACKIT limits SKE cluster names to 11 characters."

  validation {
    condition     = length(var.cluster_name) >= 1 && length(var.cluster_name) <= 11
    error_message = "SKE cluster names are limited to 11 characters."
  }

  validation {
    condition     = can(regex("^[a-z0-9]([a-z0-9-]*[a-z0-9])?$", var.cluster_name))
    error_message = "SKE cluster names may contain lowercase letters, digits and hyphens, and must start and end with a letter or a digit."
  }
}

variable "stackit_region" {
  type        = string
  nullable    = true
  default     = "eu01"
  description = "STACKIT region the provider talks to. Ignored when the caller supplies its own provider configuration."
}

variable "service_account_email" {
  type        = string
  nullable    = true
  default     = null
  description = "Email of the STACKIT service account the provider authenticates as via workload identity federation. Leave unset when the caller supplies its own provider configuration."
}

variable "node_pools" {
  type = list(object({
    name                    = string
    machine_type            = string
    minimum                 = number
    maximum                 = number
    availability_zones      = list(string)
    max_surge               = optional(number)
    max_unavailable         = optional(number)
    allow_system_components = optional(bool)
    labels                  = optional(map(string))
    os_name                 = optional(string)
    os_version_min          = optional(string)
    volume_type             = optional(string)
    volume_size             = optional(number)
  }))
  nullable = false

  default = [
    {
      name               = "pool-1"
      machine_type       = "g2i.2" # general instances
      minimum            = 1
      maximum            = 3
      availability_zones = ["eu01-1"]
      max_surge          = 1
    }
  ]

  description = "Node pools of the cluster. The default is a single autoscaling pool of general instances, which is what the meshcloud foundations run today."
}

variable "maintenance" {
  type = object({
    enable_kubernetes_version_updates    = optional(bool, true)
    enable_machine_image_version_updates = optional(bool, true)
    start                                = optional(string, "01:00:00Z")
    end                                  = optional(string, "02:00:00Z")
  })
  nullable = false
  default  = {}

  description = "Maintenance window in which SKE applies Kubernetes and machine image updates."
}

variable "network_id" {
  type        = string
  nullable    = true
  default     = null
  description = "UUID of the STACKIT Network Area (SNA) network the cluster is deployed into. Feed this from the `network_id` output of `modules/stackit/network`. Leave unset to let SKE place the cluster on its own network."
}

variable "control_plane_access_scope" {
  type        = string
  nullable    = true
  default     = null
  description = "Access scope of the control plane, either `PUBLIC` or `SNA`. Leave unset to get a public control plane, which is what SKE creates by default. The field is immutable after creation, it is feature-flagged per organization or project, and it cannot be combined with the ACL extension."

  validation {
    condition     = var.control_plane_access_scope == null ? true : contains(["PUBLIC", "SNA"], var.control_plane_access_scope)
    error_message = "control_plane_access_scope must be either PUBLIC or SNA."
  }
}

variable "dns_extension" {
  type = object({
    enabled     = optional(bool, true)
    zones       = optional(list(string))
    gateway_api = optional(bool)
  })
  nullable    = true
  default     = null
  description = "SKE managed ExternalDNS extension. Leave unset to keep the extension off. `zones` is the domain filter ExternalDNS applies, for example `[\"apps.example.runs.onstackit.cloud\"]`."
}

variable "kubeconfig_expiration_seconds" {
  type        = number
  nullable    = false
  default     = 15552000 # 180 days
  description = "Lifetime of the generated kubeconfig in seconds. Terraform refreshes the kubeconfig once it reaches half of this lifetime."
}
