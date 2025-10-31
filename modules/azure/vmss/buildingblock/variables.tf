variable "vmss_name" {
  type        = string
  description = "The name of the Virtual Machine Scale Set"
  validation {
    condition     = can(regex("^[a-z0-9-]{1,64}$", var.vmss_name))
    error_message = "vmss_name must be 1-64 characters, lowercase alphanumeric and hyphens only"
  }
}

variable "resource_group_name" {
  type        = string
  description = "The name of the resource group where resources will be created"
}

variable "location" {
  type        = string
  description = "The Azure region where resources will be deployed"
}

variable "vnet_name" {
  type        = string
  description = "The name of the existing virtual network (spoke VNet)"
}

variable "vnet_resource_group_name" {
  type        = string
  description = "The name of the resource group containing the virtual network"
}

variable "subnet_name" {
  type        = string
  description = "The name of the existing subnet where VMSS will be deployed"
}

variable "os_type" {
  type        = string
  description = "The operating system type (Linux or Windows)"
  default     = "Linux"
  validation {
    condition     = contains(["Linux", "Windows"], var.os_type)
    error_message = "os_type must be either 'Linux' or 'Windows'"
  }
}

variable "sku" {
  type        = string
  description = "The SKU of the Virtual Machine Scale Set (instance size)"
  default     = "Standard_B2s"
}

variable "instances" {
  type        = number
  description = "The initial number of instances in the scale set"
  default     = 2
  validation {
    condition     = var.instances >= 0 && var.instances <= 1000
    error_message = "instances must be between 0 and 1000"
  }
}

variable "admin_username" {
  type        = string
  description = "The admin username for the VM instances"
  default     = "azureuser"
}

variable "admin_password" {
  type        = string
  description = "The admin password for Windows VM instances (required for Windows)"
  default     = null
  sensitive   = true
}

variable "ssh_public_key" {
  type        = string
  description = "SSH public key for Linux VM authentication (required for Linux)"
  default     = null
}

variable "enable_autoscaling" {
  type        = bool
  description = "Enable autoscaling based on CPU metrics"
  default     = false
}

variable "min_instances" {
  type        = number
  description = "Minimum number of instances when autoscaling is enabled"
  default     = 2
  validation {
    condition     = var.min_instances >= 1 && var.min_instances <= 1000
    error_message = "min_instances must be between 1 and 1000"
  }
}

variable "max_instances" {
  type        = number
  description = "Maximum number of instances when autoscaling is enabled"
  default     = 10
  validation {
    condition     = var.max_instances >= 1 && var.max_instances <= 1000
    error_message = "max_instances must be between 1 and 1000"
  }
}

variable "scale_out_cpu_threshold" {
  type        = number
  description = "CPU percentage threshold to trigger scale out"
  default     = 75
  validation {
    condition     = var.scale_out_cpu_threshold > 0 && var.scale_out_cpu_threshold <= 100
    error_message = "scale_out_cpu_threshold must be between 1 and 100"
  }
}

variable "scale_in_cpu_threshold" {
  type        = number
  description = "CPU percentage threshold to trigger scale in"
  default     = 25
  validation {
    condition     = var.scale_in_cpu_threshold > 0 && var.scale_in_cpu_threshold <= 100
    error_message = "scale_in_cpu_threshold must be between 1 and 100"
  }
}

variable "os_disk_storage_type" {
  type        = string
  description = "The storage account type for the OS disk"
  default     = "Standard_LRS"
  validation {
    condition     = contains(["Standard_LRS", "StandardSSD_LRS", "Premium_LRS", "StandardSSD_ZRS", "Premium_ZRS"], var.os_disk_storage_type)
    error_message = "os_disk_storage_type must be a valid Azure storage type"
  }
}

variable "os_disk_size_gb" {
  type        = number
  description = "The size of the OS disk in GB"
  default     = 30
  validation {
    condition     = var.os_disk_size_gb >= 30 && var.os_disk_size_gb <= 4095
    error_message = "os_disk_size_gb must be between 30 and 4095"
  }
}

variable "image_publisher" {
  type        = string
  description = "The publisher of the image"
  default     = "Canonical"
}

variable "image_offer" {
  type        = string
  description = "The offer of the image"
  default     = "0001-com-ubuntu-server-jammy"
}

variable "image_sku" {
  type        = string
  description = "The SKU of the image"
  default     = "22_04-lts-gen2"
}

variable "image_version" {
  type        = string
  description = "The version of the image"
  default     = "latest"
}

variable "upgrade_mode" {
  type        = string
  description = "Upgrade policy mode for the scale set (Automatic, Manual, Rolling)"
  default     = "Manual"
  validation {
    condition     = contains(["Automatic", "Manual", "Rolling"], var.upgrade_mode)
    error_message = "upgrade_mode must be one of: Automatic, Manual, Rolling"
  }
}

variable "health_probe_protocol" {
  type        = string
  description = "Protocol for health probe (Http, Https, Tcp) - required when upgrade_mode is Automatic or Rolling"
  default     = "Http"
  validation {
    condition     = contains(["Http", "Https", "Tcp"], var.health_probe_protocol)
    error_message = "health_probe_protocol must be one of: Http, Https, Tcp"
  }
}

variable "health_probe_port" {
  type        = number
  description = "Port for health probe - required when upgrade_mode is Automatic or Rolling"
  default     = 80
  validation {
    condition     = var.health_probe_port > 0 && var.health_probe_port <= 65535
    error_message = "health_probe_port must be between 1 and 65535"
  }
}

variable "health_probe_request_path" {
  type        = string
  description = "Request path for HTTP/HTTPS health probe - required for Http/Https protocol"
  default     = "/"
}

variable "enable_load_balancer" {
  type        = bool
  description = "Enable Azure Load Balancer for the scale set"
  default     = true
}

variable "load_balancer_sku" {
  type        = string
  description = "SKU of the Load Balancer (Basic or Standard)"
  default     = "Standard"
  validation {
    condition     = contains(["Basic", "Standard"], var.load_balancer_sku)
    error_message = "load_balancer_sku must be either 'Basic' or 'Standard'"
  }
}

variable "enable_public_ip" {
  type        = bool
  description = "Enable public IP for the load balancer"
  default     = false
}

variable "backend_port" {
  type        = number
  description = "Backend port for load balancer rule"
  default     = 80
  validation {
    condition     = var.backend_port > 0 && var.backend_port <= 65535
    error_message = "backend_port must be between 1 and 65535"
  }
}

variable "frontend_port" {
  type        = number
  description = "Frontend port for load balancer rule"
  default     = 80
  validation {
    condition     = var.frontend_port > 0 && var.frontend_port <= 65535
    error_message = "frontend_port must be between 1 and 65535"
  }
}

variable "enable_ssh_access" {
  type        = bool
  description = "Enable SSH access (port 22) through NSG for Linux VMs"
  default     = false
}

variable "enable_rdp_access" {
  type        = bool
  description = "Enable RDP access (port 3389) through NSG for Windows VMs"
  default     = false
}

variable "custom_data" {
  type        = string
  description = "Custom data script to run on VM initialization (cloud-init for Linux, PowerShell for Windows)"
  default     = null
}

variable "enable_boot_diagnostics" {
  type        = bool
  description = "Enable boot diagnostics for VM instances"
  default     = true
}

variable "zones" {
  type        = list(string)
  description = "Availability zones to spread instances across (e.g., [1, 2, 3])"
  default     = []
  validation {
    condition = alltrue([
      for z in var.zones : contains(["1", "2", "3"], z)
    ])
    error_message = "zones must contain only valid zone numbers: 1, 2, or 3"
  }
}

variable "overprovision" {
  type        = bool
  description = "Overprovision VMs to improve deployment success rate"
  default     = true
}

variable "single_placement_group" {
  type        = bool
  description = "Limit scale set to single placement group (max 100 instances)"
  default     = true
}

variable "enable_spot_instances" {
  type        = bool
  description = "Enable spot instances for significant cost savings (VMs can be evicted)"
  default     = false
}

variable "spot_eviction_policy" {
  type        = string
  description = "Eviction policy for spot instances (Deallocate or Delete)"
  default     = "Deallocate"
  validation {
    condition     = contains(["Deallocate", "Delete"], var.spot_eviction_policy)
    error_message = "spot_eviction_policy must be either 'Deallocate' or 'Delete'"
  }
}

variable "spot_max_bid_price" {
  type        = number
  description = "Maximum price per hour for spot instances. -1 means pay up to on-demand price"
  default     = -1
}

variable "tags" {
  type        = map(string)
  description = "Tags to apply to all resources"
  default     = {}
}
