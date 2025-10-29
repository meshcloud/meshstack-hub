variable "resource_group_name" {
  type        = string
  description = "Name of the resource group to create for the AKS cluster"
  default     = "aks-prod-rg"
}

variable "location" {
  type        = string
  description = "Azure region where resources will be deployed"
  default     = "Germany West Central"
}

variable "aks_cluster_name" {
  type        = string
  description = "Name of the AKS cluster"
  default     = "prod-aks"

  validation {
    condition     = length(var.aks_cluster_name) >= 1 && length(var.aks_cluster_name) <= 63
    error_message = "AKS cluster name must be between 1 and 63 characters."
  }
}

variable "dns_prefix" {
  type        = string
  description = "DNS prefix for the AKS cluster"
  default     = "prodaks"

  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9-]{0,53}[a-z0-9]$", var.dns_prefix))
    error_message = "DNS prefix must contain only lowercase letters, numbers, and hyphens, and be between 2 and 54 characters."
  }
}

variable "vnet_address_space" {
  type        = string
  description = "Address space for the AKS virtual network"
  default     = "10.240.0.0/16"

  validation {
    condition     = can(cidrhost(var.vnet_address_space, 0))
    error_message = "VNet address space must be a valid CIDR block."
  }
}

variable "subnet_address_prefix" {
  type        = string
  description = "Address prefix for the AKS subnet"
  default     = "10.240.0.0/20"

  validation {
    condition     = can(cidrhost(var.subnet_address_prefix, 0))
    error_message = "Subnet address prefix must be a valid CIDR block."
  }
}

variable "service_cidr" {
  type        = string
  description = "CIDR for Kubernetes services (must not overlap with VNet or subnet)"
  default     = "10.0.0.0/16"

  validation {
    condition     = can(cidrhost(var.service_cidr, 0))
    error_message = "Service CIDR must be a valid CIDR block."
  }
}

variable "dns_service_ip" {
  type        = string
  description = "IP address for Kubernetes DNS service (must be within service_cidr)"
  default     = "10.0.0.10"

  validation {
    condition     = can(regex("^(?:[0-9]{1,3}\\.){3}[0-9]{1,3}$", var.dns_service_ip))
    error_message = "DNS service IP must be a valid IP address."
  }
}

variable "node_count" {
  type        = number
  description = "Initial number of nodes in the default node pool"
  default     = 3

  validation {
    condition     = var.node_count >= 1 && var.node_count <= 1000
    error_message = "Node count must be between 1 and 1000."
  }
}

variable "min_node_count" {
  type        = number
  description = "Minimum number of nodes for auto-scaling (set to enable auto-scaling)"
  default     = null
}

variable "max_node_count" {
  type        = number
  description = "Maximum number of nodes for auto-scaling (set to enable auto-scaling)"
  default     = null
}

variable "vm_size" {
  type        = string
  description = "Size of the virtual machines for the default node pool"
  default     = "Standard_DS3_v2"
}

variable "os_disk_size_gb" {
  type        = number
  description = "OS disk size in GB for the node pool"
  default     = 100

  validation {
    condition     = var.os_disk_size_gb >= 30 && var.os_disk_size_gb <= 2048
    error_message = "OS disk size must be between 30 and 2048 GB."
  }
}

variable "kubernetes_version" {
  type        = string
  description = "Kubernetes version for the AKS cluster"
  default     = "1.33.0"

  validation {
    condition     = can(regex("^[0-9]+\\.[0-9]+\\.[0-9]+$", var.kubernetes_version))
    error_message = "Kubernetes version must be in format X.Y.Z (e.g., 1.29.2)."
  }
}

variable "aks_admin_group_object_id" {
  type        = string
  description = "Object ID of the Azure AD group used for AKS admin access. If null, Azure AD RBAC will not be configured."
  default     = null

  validation {
    condition     = var.aks_admin_group_object_id == null || can(regex("^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$", var.aks_admin_group_object_id))
    error_message = "Admin group object ID must be a valid GUID or null."
  }
}

variable "log_analytics_workspace_name" {
  type        = string
  description = "Name of the Log Analytics Workspace. If null, no LAW or monitoring will be created."
  default     = null
}

variable "log_retention_days" {
  type        = number
  description = "Number of days to retain logs in Log Analytics Workspace"
  default     = 30

  validation {
    condition     = var.log_retention_days >= 30 && var.log_retention_days <= 730
    error_message = "Log retention must be between 30 and 730 days."
  }
}

variable "enable_auto_scaling" {
  type        = bool
  description = "Enable auto-scaling for the default node pool"
  default     = false
}

variable "network_plugin" {
  type        = string
  description = "Network plugin to use (azure or kubenet)"
  default     = "azure"

  validation {
    condition     = contains(["azure", "kubenet"], var.network_plugin)
    error_message = "Network plugin must be either 'azure' or 'kubenet'."
  }
}

variable "network_policy" {
  type        = string
  description = "Network policy to use (azure, calico, or cilium)"
  default     = "azure"

  validation {
    condition     = contains(["azure", "calico", "cilium"], var.network_policy)
    error_message = "Network policy must be 'azure', 'calico', or 'cilium'."
  }
}

variable "tags" {
  type        = map(string)
  description = "Tags to apply to all resources"
  default     = {}
}
