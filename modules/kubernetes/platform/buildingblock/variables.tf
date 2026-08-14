variable "kube_host" {
  type        = string
  nullable    = false
  description = "URL of the Kubernetes API server, for example `https://k8s.example.com:6443`. meshStack calls this URL to replicate tenants and to collect metering data."
}

variable "cluster_ca_certificate" {
  type        = string
  nullable    = true
  default     = null
  description = "PEM encoded CA certificate of the cluster. Leave unset when the caller supplies its own provider configuration."
}

variable "client_certificate" {
  type        = string
  nullable    = true
  default     = null
  sensitive   = true
  description = "PEM encoded client certificate the module authenticates with while it creates the in-cluster service accounts. Leave unset when the caller supplies its own provider configuration."
}

variable "client_key" {
  type        = string
  nullable    = true
  default     = null
  sensitive   = true
  description = "PEM encoded client key that belongs to `client_certificate`. Leave unset when the caller supplies its own provider configuration."
}

variable "owning_workspace_identifier" {
  type        = string
  nullable    = false
  description = "Identifier of the meshStack workspace that owns the platform and its landing zones."
}

variable "location_identifier" {
  type        = string
  nullable    = false
  description = "Identifier of the meshStack location the platform is registered in."
}

variable "platform_name" {
  type        = string
  nullable    = false
  default     = "ske-namespace"
  description = "meshStack platform identifier. The landing zones derive their names from it, for example `ske-namespace-dev`."
}

variable "platform_display_name" {
  type        = string
  nullable    = false
  default     = "Kubernetes namespace on SKE"
  description = "Name of the platform as users see it in meshPanel."
}

variable "platform_description" {
  type        = string
  nullable    = false
  default     = "Provides a kubernetes namespace on STACKIT Kubernetes Engine (SKE)."
  description = "Description of the platform as users see it in meshPanel."
}

variable "documentation_url" {
  type        = string
  nullable    = false
  default     = ""
  description = "Link to the platform documentation shown in meshPanel."
}

variable "support_url" {
  type        = string
  nullable    = false
  default     = ""
  description = "Link to the support channel shown in meshPanel."
}

variable "namespace_name_pattern" {
  type        = string
  nullable    = false
  default     = "#{workspaceIdentifier}-#{projectIdentifier}"
  description = "Pattern meshStack uses to name the namespace it creates for a tenant."
}

variable "disable_ssl_validation" {
  type        = bool
  nullable    = false
  default     = true
  description = "Skip SSL validation when meshStack calls the Kubernetes API server. SKE clusters serve a certificate that meshStack does not trust by default, which is why this is on."
}

variable "service_account_namespace" {
  type        = string
  nullable    = false
  default     = "meshcloud"
  description = "Namespace that holds the replicator and metering service accounts."
}

variable "resource_name_suffix" {
  type        = string
  nullable    = false
  default     = ""
  description = "Suffix appended to the in-cluster resource names. Set it when one cluster carries more than one meshStack platform registration, so the service accounts and cluster roles do not collide."
}

variable "metering_enabled" {
  type        = bool
  nullable    = false
  default     = true
  description = "Create the metering service account and register metering on the platform. Turn this off when meshStack should not collect usage data from the cluster."
}

variable "metering_processing" {
  type = object({
    compact_timelines_after_days = optional(number, 30)
    delete_raw_data_after_days   = optional(number, 65)
  })
  nullable    = false
  default     = {}
  description = "How long meshMetering keeps timelines and raw data. Only used when `metering_enabled` is true."
}

variable "replicator_additional_rules" {
  type = list(object({
    api_groups        = list(string)
    resources         = list(string)
    verbs             = list(string)
    resource_names    = optional(list(string))
    non_resource_urls = optional(list(string))
  }))
  nullable    = false
  default     = []
  description = "Extra RBAC rules added to the replicator cluster role."
}

variable "metering_additional_rules" {
  type = list(object({
    api_groups        = list(string)
    resources         = list(string)
    verbs             = list(string)
    resource_names    = optional(list(string))
    non_resource_urls = optional(list(string))
  }))
  nullable    = false
  default     = []
  description = "Extra RBAC rules added to the metering cluster role."
}

# Cluster sizing behind the defaults: 2 vCPU + 8 Gi RAM per node, 1 node default and 3 nodes max.
# Expected density is 20-30 namespaces across the cluster. CPU is given in millicores (m) and
# memory in mebibytes (Mi) so every value stays a whole integer.
variable "quota_definitions" {
  type = list(object({
    quota_key               = string
    label                   = string
    description             = string
    unit                    = string
    min_value               = number
    max_value               = number
    auto_approval_threshold = number
  }))
  nullable    = false
  description = "Quota keys a tenant can request on this platform, with the upper bound and the threshold below which meshStack approves a request automatically."

  default = [
    {
      quota_key               = "limits.cpu"
      label                   = "CPU limit"
      description             = "The sum of CPU limits across all pods in a non-terminal state cannot exceed this value."
      unit                    = "m"
      min_value               = 0
      max_value               = 1000 # 1 vCPU per namespace
      auto_approval_threshold = 1000
    },
    {
      quota_key               = "requests.cpu"
      label                   = "CPU requests"
      description             = "The sum of CPU requests across all pods in a non-terminal state cannot exceed this value."
      unit                    = "m"
      min_value               = 0
      max_value               = 1000
      auto_approval_threshold = 500
    },
    {
      quota_key               = "limits.memory"
      label                   = "Memory limit"
      description             = "The sum of memory limits across all pods in a non-terminal state cannot exceed this value."
      unit                    = "Mi"
      min_value               = 0
      max_value               = 1024 # 1 Gi per namespace
      auto_approval_threshold = 1024
    },
    {
      quota_key               = "requests.memory"
      label                   = "Memory requests"
      description             = "The sum of memory requests across all pods in a non-terminal state cannot exceed this value."
      unit                    = "Mi"
      min_value               = 0
      max_value               = 1024
      auto_approval_threshold = 512
    },
    {
      quota_key               = "requests.storage"
      label                   = "Total Storage Requests"
      description             = "Across all persistent volume claims, the sum of storage requests cannot exceed this value."
      unit                    = "Gi"
      min_value               = 0
      max_value               = 5
      auto_approval_threshold = 2
    },
    {
      quota_key               = "persistentvolumeclaims"
      label                   = "Persistent Volume Claims"
      description             = "The total number of PersistentVolumeClaims that can exist in the namespace."
      unit                    = ""
      min_value               = 0
      max_value               = 4
      auto_approval_threshold = 2
    },
  ]
}

variable "landing_zones" {
  type = map(object({
    display_name = string
    description  = string
    info_link    = optional(string, "")
    tags         = optional(map(list(string)), {})
    quotas       = optional(list(object({ key = string, value = number })), [])
  }))
  nullable    = false
  description = "Landing zones to create for the platform, keyed by environment. The key becomes the suffix of the landing zone identifier, for example `dev` gives `ske-namespace-dev`."

  default = {
    dev = {
      display_name = "SKE Kubernetes Namespace – Development"
      description  = "Landing zone for development workloads."
      tags = {
        "LandingZoneFamily" = ["cloud-native"]
        "environment"       = ["dev"]
        "confidentiality"   = ["internal"]
      }
      quotas = [
        { key = "limits.cpu", value = 500 },
        { key = "requests.cpu", value = 250 },
        { key = "limits.memory", value = 512 },
        { key = "requests.memory", value = 256 },
        { key = "requests.storage", value = 1 },
        { key = "persistentvolumeclaims", value = 2 },
      ]
    }
    prod = {
      display_name = "SKE Kubernetes Namespace – Production"
      description  = "Landing zone for production workloads."
      tags = {
        "LandingZoneFamily" = ["cloud-native"]
        "environment"       = ["prod"]
        "confidentiality"   = ["public"]
      }
      quotas = [
        { key = "limits.cpu", value = 1000 },
        { key = "requests.cpu", value = 500 },
        { key = "limits.memory", value = 1024 },
        { key = "requests.memory", value = 512 },
        { key = "requests.storage", value = 2 },
        { key = "persistentvolumeclaims", value = 4 },
      ]
    }
  }
}
