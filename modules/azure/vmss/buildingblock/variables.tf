variable "vmss_name" {
  type        = string
  description = "Name of the Virtual Machine Scale Set"
}

variable "resource_group_name" {
  type        = string
  description = "Name of the resource group"
}

variable "location" {
  type        = string
  description = "Azure region where resources will be deployed"
}

variable "sku" {
  type        = string
  description = "The SKU/size of the virtual machines in the scale set"
  default     = "Standard_B2s"
}

variable "instances" {
  type        = number
  description = "Initial number of VM instances in the scale set"
  default     = 2
  validation {
    condition     = var.instances >= 0 && var.instances <= 1000
    error_message = "instances must be between 0 and 1000"
  }
}

variable "os_type" {
  type        = string
  description = "Operating system type (Linux or Windows)"
  default     = "Linux"
  validation {
    condition     = contains(["Linux", "Windows"], var.os_type)
    error_message = "os_type must be either 'Linux' or 'Windows'"
  }
}

variable "admin_username" {
  type        = string
  description = "Admin username for the VM instances"
  default     = "azureuser"
}

variable "admin_password" {
  type        = string
  description = "Admin password for Windows VMs (required for Windows)"
  default     = null
  sensitive   = true
}

variable "ssh_public_key" {
  type        = string
  description = "SSH public key for Linux VM authentication (required for Linux)"
  default     = null
}

variable "vnet_address_space" {
  type        = string
  description = "Address space for the virtual network"
  default     = "10.0.0.0/16"
}

variable "subnet_address_prefix" {
  type        = string
  description = "Address prefix for the subnet"
  default     = "10.0.1.0/24"
}

variable "os_disk_storage_type" {
  type        = string
  description = "Storage account type for OS disk"
  default     = "Standard_LRS"
  validation {
    condition     = contains(["Standard_LRS", "StandardSSD_LRS", "Premium_LRS", "StandardSSD_ZRS", "Premium_ZRS"], var.os_disk_storage_type)
    error_message = "os_disk_storage_type must be a valid Azure storage type"
  }
}

variable "os_disk_size_gb" {
  type        = number
  description = "Size of the OS disk in GB"
  default     = 30
}

variable "image_publisher" {
  type        = string
  description = "Publisher of the VM image"
  default     = "Canonical"
}

variable "image_offer" {
  type        = string
  description = "Offer of the VM image"
  default     = "0001-com-ubuntu-server-jammy"
}

variable "image_sku" {
  type        = string
  description = "SKU of the VM image"
  default     = "22_04-lts-gen2"
}

variable "image_version" {
  type        = string
  description = "Version of the VM image"
  default     = "latest"
}

variable "enable_autoscaling" {
  type        = bool
  description = "Enable autoscaling for the scale set"
  default     = false
}

variable "autoscale_min" {
  type        = number
  description = "Minimum number of instances when autoscaling"
  default     = 1
  validation {
    condition     = var.autoscale_min >= 1 && var.autoscale_min <= 1000
    error_message = "autoscale_min must be between 1 and 1000"
  }
}

variable "autoscale_max" {
  type        = number
  description = "Maximum number of instances when autoscaling"
  default     = 10
  validation {
    condition     = var.autoscale_max >= 1 && var.autoscale_max <= 1000
    error_message = "autoscale_max must be between 1 and 1000"
  }
}

variable "autoscale_default" {
  type        = number
  description = "Default number of instances when autoscaling"
  default     = 2
  validation {
    condition     = var.autoscale_default >= 1 && var.autoscale_default <= 1000
    error_message = "autoscale_default must be between 1 and 1000"
  }
}

variable "cpu_scale_out_threshold" {
  type        = number
  description = "CPU percentage threshold to trigger scale out"
  default     = 75
  validation {
    condition     = var.cpu_scale_out_threshold > 0 && var.cpu_scale_out_threshold <= 100
    error_message = "cpu_scale_out_threshold must be between 1 and 100"
  }
}

variable "cpu_scale_in_threshold" {
  type        = number
  description = "CPU percentage threshold to trigger scale in"
  default     = 25
  validation {
    condition     = var.cpu_scale_in_threshold > 0 && var.cpu_scale_in_threshold <= 100
    error_message = "cpu_scale_in_threshold must be between 1 and 100"
  }
}

variable "enable_load_balancer" {
  type        = bool
  description = "Create and attach a load balancer to the scale set"
  default     = true
}

variable "enable_public_ip" {
  type        = bool
  description = "Create a public IP for the load balancer"
  default     = true
}

variable "health_probe_protocol" {
  type        = string
  description = "Protocol for health probe (Http or Tcp)"
  default     = "Tcp"
  validation {
    condition     = contains(["Http", "Tcp"], var.health_probe_protocol)
    error_message = "health_probe_protocol must be either 'Http' or 'Tcp'"
  }
}

variable "health_probe_port" {
  type        = number
  description = "Port for health probe"
  default     = 80
}

variable "health_probe_path" {
  type        = string
  description = "Path for HTTP health probe (only used if protocol is Http)"
  default     = "/"
}

variable "lb_rules" {
  type = list(object({
    name          = string
    frontend_port = number
    backend_port  = number
    protocol      = string
  }))
  description = "Load balancer rules for traffic distribution"
  default = [{
    name          = "http"
    frontend_port = 80
    backend_port  = 80
    protocol      = "Tcp"
  }]
}

variable "upgrade_mode" {
  type        = string
  description = "Upgrade mode for the scale set (Manual, Automatic, Rolling)"
  default     = "Manual"
  validation {
    condition     = contains(["Manual", "Automatic", "Rolling"], var.upgrade_mode)
    error_message = "upgrade_mode must be one of: Manual, Automatic, Rolling"
  }
}

variable "enable_spot_instances" {
  type        = bool
  description = "Enable spot instances for cost savings"
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
  description = "Maximum price to pay for spot instance per hour. -1 means pay up to on-demand price"
  default     = -1
}

variable "custom_data" {
  type        = string
  description = "Custom data script to run on VM initialization (base64 encoded)"
  default     = null
}

variable "zones" {
  type        = list(string)
  description = "Availability zones for the scale set"
  default     = []
}

variable "tags" {
  type        = map(string)
  description = "Tags to apply to all resources"
  default     = {}
}
