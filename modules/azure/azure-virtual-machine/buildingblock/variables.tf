variable "vm_name" {
  type        = string
  description = "The name of the virtual machine"
}

variable "resource_group_name" {
  type        = string
  description = "The name of the resource group. If not provided, a new resource group will be created."
  default     = null
}

variable "location" {
  type        = string
  description = "The Azure region where resources will be deployed"
}

variable "vnet_address_space" {
  type        = string
  description = "The address space for the virtual network"
  default     = "10.0.0.0/16"
}

variable "subnet_address_prefix" {
  type        = string
  description = "The address prefix for the subnet"
  default     = "10.0.1.0/24"
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

variable "vm_size" {
  type        = string
  description = "The size of the virtual machine"
  default     = "Standard_B1s"
}

variable "admin_username" {
  type        = string
  description = "The admin username for the VM"
  default     = "azureuser"
}

variable "admin_password" {
  type        = string
  description = "The admin password for Windows VM (required for Windows)"
  default     = null
  sensitive   = true
}

variable "ssh_public_key" {
  type        = string
  description = "SSH public key for Linux VM authentication (required for Linux)"
  default     = null
}

variable "enable_public_ip" {
  type        = bool
  description = "Whether to create and assign a public IP address to the VM"
  default     = false
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
}

variable "data_disk_size_gb" {
  type        = number
  description = "The size of the data disk in GB. Set to 0 to skip data disk creation"
  default     = 0
}

variable "data_disk_storage_type" {
  type        = string
  description = "The storage account type for the data disk"
  default     = "Standard_LRS"
  validation {
    condition     = contains(["Standard_LRS", "StandardSSD_LRS", "Premium_LRS", "StandardSSD_ZRS", "Premium_ZRS"], var.data_disk_storage_type)
    error_message = "data_disk_storage_type must be a valid Azure storage type"
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

variable "tags" {
  type        = map(string)
  description = "Tags to apply to all resources"
  default     = {}
}

variable "enable_spot_instance" {
  type        = bool
  description = "Enable spot instance for significant cost savings (VM can be evicted when Azure needs capacity)"
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
  description = "Maximum price to pay for spot instance per hour. -1 means pay up to on-demand price. Default is -1 for maximum availability"
  default     = -1
}
