variable "datacenter_id" {
  description = "ID of the IONOS datacenter where the VM will be deployed"
  type        = string
}

variable "vm_name" {
  description = "Name of the virtual machine"
  type        = string

  validation {
    condition     = length(var.vm_name) > 0 && length(var.vm_name) <= 63
    error_message = "VM name must be between 1 and 63 characters."
  }
}

variable "template" {
  description = "VM template preset (small, medium, large) or custom. If custom, use vm_specs."
  type        = string
  default     = "custom"

  validation {
    condition     = contains(["small", "medium", "large", "custom"], var.template)
    error_message = "Template must be one of: small, medium, large, or custom."
  }
}

variable "vm_specs" {
  description = "Custom VM specifications (used when template is 'custom')"
  type = object({
    cpu_cores    = number
    memory_mb    = number
    storage_gb   = number
    storage_type = optional(string, "SSD")
    os_image     = string
  })
  default = null

  validation {
    condition = var.vm_specs == null || (
      var.vm_specs.cpu_cores > 0 &&
      var.vm_specs.cpu_cores <= 96 &&
      var.vm_specs.memory_mb > 0 &&
      var.vm_specs.memory_mb <= 1048576 &&
      var.vm_specs.storage_gb > 0 &&
      var.vm_specs.storage_gb <= 65536
    )
    error_message = "VM specs must have valid ranges: cpu_cores (1-96), memory_mb (1-1048576), storage_gb (1-65536)."
  }
}

variable "create_network_interface" {
  description = "Whether to create a new network interface for the VM"
  type        = bool
  default     = true
}

variable "network_id" {
  description = "ID of the network to attach the VM to (required if create_network_interface is false)"
  type        = string
  default     = null
}

variable "public_ip_required" {
  description = "Whether a public IP should be assigned to the VM"
  type        = bool
  default     = true
}

variable "additional_data_disks" {
  description = "List of additional data disks to attach to the VM"
  type = list(object({
    name         = string
    size_gb      = number
    storage_type = optional(string, "SSD")
  }))
  default = []
}

variable "tags" {
  description = "Tags to apply to the VM and related resources"
  type        = map(string)
  default     = {}
}

locals {
  # Template presets
  templates = {
    small = {
      cpu_cores    = 2
      memory_mb    = 4096
      storage_gb   = 50
      storage_type = "SSD"
    }
    medium = {
      cpu_cores    = 4
      memory_mb    = 8192
      storage_gb   = 100
      storage_type = "SSD"
    }
    large = {
      cpu_cores    = 8
      memory_mb    = 16384
      storage_gb   = 200
      storage_type = "SSD"
    }
  }

  # Determine which specs to use
  effective_specs = var.template != "custom" ? local.templates[var.template] : var.vm_specs

  # Validation for network configuration
  validate_network = (
    var.create_network_interface == false && var.network_id == null
  ) ? file("ERROR: network_id must be provided when create_network_interface is false") : null
}
