variable "workspace_identifier" {
  type        = string
  description = "The identifier of the meshStack workspace"
}

variable "name" {
  type        = string
  description = "This name will be used for the created project and VM"
}

variable "full_platform_identifier" {
  type        = string
  description = "Full platform identifier of the Azure platform."
}

variable "landing_zone_identifier" {
  type        = string
  description = "Azure Landing zone identifier for the tenant."
}

variable "azure_vm_definition_version_uuid" {
  type        = string
  description = "UUID of the Azure Virtual Machine building block definition version."
}

variable "creator" {
  type = object({
    type        = string
    identifier  = string
    displayName = string
    username    = optional(string)
    email       = optional(string)
    euid        = optional(string)
  })
  description = "Information about the creator of the resources who will be assigned Project Admin role"
}

variable "project_tags_yaml" {
  type        = string
  description = <<EOF
YAML configuration for project tags. Expected structure:

```yaml
key1:
  - "value1"
  - "value2"
key2:
  - "value3"
```
EOF
  default     = "{}"

  validation {
    condition     = can(yamldecode(var.project_tags_yaml))
    error_message = "project_tags_yaml must be valid YAML"
  }
}

# Azure VM specific variables
variable "vm_location" {
  type        = string
  description = "The Azure region where the VM will be deployed."
  default     = "westeurope"
}

variable "vm_os_type" {
  type        = string
  description = "The operating system type (Linux or Windows)."
  default     = "Linux"
  validation {
    condition     = contains(["Linux", "Windows"], var.vm_os_type)
    error_message = "vm_os_type must be either 'Linux' or 'Windows'"
  }
}

variable "vm_size" {
  type        = string
  description = "The size of the virtual machine."
  default     = "Standard_B1s"
}

variable "vm_admin_username" {
  type        = string
  description = "The admin username for the VM."
  default     = "azureuser"
}

variable "vm_ssh_public_key" {
  type        = string
  description = "SSH public key for Linux VM authentication (required for Linux)."
  default     = null
}

variable "vm_admin_password" {
  type        = string
  description = "The admin password for Windows VM (required for Windows)."
  default     = null
  sensitive   = true
}

variable "vm_enable_public_ip" {
  type        = bool
  description = "Whether to create and assign a public IP address to the VM."
  default     = false
}
