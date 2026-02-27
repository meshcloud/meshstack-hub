variable "stackit_project_id" {
  type        = string
  description = "STACKIT project ID where the SKE cluster will be created."
}

variable "cluster_name" {
  type        = string
  description = "Name of the SKE cluster."
  default     = "ske-cluster"
}

variable "region" {
  type        = string
  description = "STACKIT region for the SKE cluster."
  default     = "eu01"
}

variable "node_count" {
  type        = number
  description = "Number of nodes in the default node pool."
  default     = 1
}

variable "machine_type" {
  type        = string
  description = "Machine type for the default node pool."
  default     = "c2i.2"
}

variable "availability_zones" {
  type        = list(string)
  description = "Availability zones for the default node pool."
  default     = ["eu01-1"]
}

variable "volume_size" {
  type        = number
  description = "Volume size in GB for nodes in the default node pool."
  default     = 25
}

variable "volume_type" {
  type        = string
  description = "Volume type for nodes in the default node pool."
  default     = "storage_premium_perf0"
}

variable "maintenance_start" {
  type        = string
  description = "Start of the maintenance window (UTC)."
  default     = "02:00:00Z"
}

variable "maintenance_end" {
  type        = string
  description = "End of the maintenance window (UTC)."
  default     = "06:00:00Z"
}

variable "enable_kubernetes_version_updates" {
  type        = bool
  description = "Enable automatic Kubernetes version updates during maintenance windows."
  default     = true
}

variable "enable_machine_image_version_updates" {
  type        = bool
  description = "Enable automatic machine image version updates during maintenance windows."
  default     = true
}

variable "meshplatform_namespace" {
  type        = string
  description = "Kubernetes namespace for the meshStack platform integration (replicator + metering service accounts)."
  default     = "meshcloud"
}
