variable "aks_cluster_name" {
  type        = string
  nullable    = false
  description = "Name of the AKS cluster"

  validation {
    condition     = length(var.aks_cluster_name) >= 1 && length(var.aks_cluster_name) <= 63
    error_message = "AKS cluster name must be between 1 and 63 characters."
  }
}

variable "resource_group_name" {
  type        = string
  nullable    = false
  description = "Name of the resource group to create for the AKS cluster"
}

variable "dns_prefix" {
  type        = string
  nullable    = false
  description = "DNS prefix for the AKS cluster"

  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9-]{0,53}[a-z0-9]$", var.dns_prefix))
    error_message = "DNS prefix must contain only lowercase letters, numbers, and hyphens, and be between 2 and 54 characters."
  }
}

variable "node_count" {
  type        = number
  nullable    = false
  description = "Initial number of nodes in the default node pool"

  validation {
    condition     = var.node_count >= 1 && var.node_count <= 1000
    error_message = "Node count must be between 1 and 1000."
  }
}

variable "vm_size" {
  type        = string
  nullable    = false
  description = "Size of the virtual machines for the default node pool"
}

variable "kubernetes_version" {
  type        = string
  description = "Kubernetes version for the AKS cluster. Null lets AKS choose the version it recommends today, 1.34 takes the latest patch in that minor, 1.34.2 pins one. A pinned version needs maintenance: AKS moves a minor to LTS-only when its community support ends, and creating a cluster on it then fails."
  default     = null

  validation {
    condition     = var.kubernetes_version == null || can(regex("^[0-9]+\\.[0-9]+(\\.[0-9]+)?$", var.kubernetes_version))
    error_message = "Kubernetes version must be X.Y or X.Y.Z (e.g. 1.34 or 1.34.2)."
  }
}

variable "private_cluster_enabled" {
  type        = bool
  nullable    = false
  description = "Enable private cluster (API server only accessible via private endpoint)"
}

variable "vnet_address_space" {
  type        = string
  nullable    = false
  description = "Address space for the AKS virtual network (only used if vnet_name is not provided)"

  validation {
    condition     = can(cidrhost(var.vnet_address_space, 0))
    error_message = "VNet address space must be a valid CIDR block."
  }
}

variable "subnet_address_prefix" {
  type        = string
  nullable    = false
  description = "Address prefix for the AKS subnet (only used if subnet_name is not provided)"

  validation {
    condition     = can(cidrhost(var.subnet_address_prefix, 0))
    error_message = "Subnet address prefix must be a valid CIDR block."
  }
}

variable "subscription_id" {
  type        = string
  nullable    = false
  description = "The Azure subscription the cluster is created in, the tenant's landing zone."
}

variable "location" {
  type        = string
  nullable    = false
  description = "Azure region where resources will be deployed"
}

variable "hub_subscription_id" {
  type        = string
  description = "Subscription ID of the hub network. Required when private_cluster_enabled is true and connecting to a hub."
  default     = null
}

variable "hub_resource_group_name" {
  type        = string
  description = "Resource group name of the hub virtual network. Required when private_cluster_enabled is true and connecting to a hub."
  default     = null
}

variable "hub_vnet_name" {
  type        = string
  description = "Name of the hub virtual network to peer with. Required when private_cluster_enabled is true and connecting to a hub."
  default     = null
}

variable "vnet_name" {
  type        = string
  description = "Name of the virtual network for AKS. If not provided, a new VNet will be created."
  default     = null
}

variable "existing_vnet_resource_group_name" {
  type        = string
  description = "Resource group name of the existing VNet. Only used when vnet_name is provided. Defaults to the AKS resource group if not specified."
  default     = null
}

variable "subnet_name" {
  type        = string
  description = "Name of the subnet for AKS. If not provided, a new subnet will be created."
  default     = null
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

variable "os_disk_size_gb" {
  type        = number
  description = "OS disk size in GB for the node pool"
  default     = 100

  validation {
    condition     = var.os_disk_size_gb >= 30 && var.os_disk_size_gb <= 2048
    error_message = "OS disk size must be between 30 and 2048 GB."
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

variable "private_dns_zone_id" {
  type        = string
  description = "Private DNS Zone ID for private cluster. Use 'System' for Azure-managed zone, or provide custom zone ID. Only used when private_cluster_enabled is true."
  default     = "System"
}

variable "private_cluster_public_fqdn_enabled" {
  type        = bool
  description = "Enable public FQDN for private cluster (allows public DNS resolution but API server remains private)"
  default     = false
}

variable "allow_gateway_transit_from_hub" {
  type        = bool
  description = "Allow gateway transit from hub to spoke. Set to true if hub has a gateway and you want spoke to use it."
  default     = false
}
