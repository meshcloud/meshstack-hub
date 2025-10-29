variable "azuredevops_org_url" {
  description = "Azure DevOps organization URL (e.g., https://dev.azure.com/myorg)"
  type        = string
}

variable "azuredevops_project_id" {
  description = "ID of the Azure DevOps project"
  type        = string
}

variable "azuredevops_pat" {
  description = "Azure DevOps Personal Access Token for agent registration"
  type        = string
  sensitive   = true
}

variable "service_endpoint_id" {
  description = "ID of the Azure service connection for VMSS management"
  type        = string
}

variable "agent_pool_name" {
  description = "Name of the Azure DevOps agent pool"
  type        = string
}

variable "vmss_name" {
  description = "Name of the Virtual Machine Scale Set"
  type        = string
}

variable "azure_subscription_id" {
  description = "Azure subscription ID where VMSS will be created"
  type        = string
}

variable "azure_resource_group_name" {
  description = "Name of the Azure resource group for VMSS"
  type        = string
}

variable "azure_location" {
  description = "Azure region for VMSS deployment"
  type        = string
}

variable "spoke_vnet_name" {
  description = "Name of the spoke virtual network"
  type        = string
}

variable "spoke_subnet_name" {
  description = "Name of the subnet in the spoke virtual network"
  type        = string
}

variable "spoke_resource_group_name" {
  description = "Name of the resource group containing the spoke virtual network"
  type        = string
}

variable "vm_sku" {
  description = "SKU of the virtual machines in the scale set"
  type        = string
  default     = "Standard_D2s_v3"
}

variable "desired_idle_agents" {
  description = "Number of idle agents to maintain"
  type        = number
  default     = 1
  validation {
    condition     = var.desired_idle_agents >= 0
    error_message = "desired_idle_agents must be greater than or equal to 0"
  }
}

variable "max_capacity" {
  description = "Maximum number of agents in the pool"
  type        = number
  default     = 10
  validation {
    condition     = var.max_capacity > 0
    error_message = "max_capacity must be greater than 0"
  }
}

variable "time_to_live_minutes" {
  description = "Time in minutes before an idle agent is removed"
  type        = number
  default     = 30
}

variable "recycle_after_each_use" {
  description = "Whether to recycle the agent after each job"
  type        = bool
  default     = false
}

variable "ssh_public_key" {
  description = "SSH public key for VM access"
  type        = string
}

variable "image_publisher" {
  description = "Publisher of the VM image"
  type        = string
  default     = "Canonical"
}

variable "image_offer" {
  description = "Offer of the VM image"
  type        = string
  default     = "0001-com-ubuntu-server-jammy"
}

variable "image_sku" {
  description = "SKU of the VM image"
  type        = string
  default     = "22_04-lts-gen2"
}

variable "image_version" {
  description = "Version of the VM image"
  type        = string
  default     = "latest"
}

variable "os_disk_type" {
  description = "Type of OS disk storage"
  type        = string
  default     = "Premium_LRS"
  validation {
    condition     = contains(["Standard_LRS", "StandardSSD_LRS", "Premium_LRS"], var.os_disk_type)
    error_message = "os_disk_type must be one of: Standard_LRS, StandardSSD_LRS, Premium_LRS"
  }
}

variable "agent_script_url" {
  description = "URL to the agent installation script"
  type        = string
  default     = "https://raw.githubusercontent.com/microsoft/azure-pipelines-agent/master/docs/start/envlinux.md"
}

variable "tags" {
  description = "Tags to apply to Azure resources"
  type        = map(string)
  default     = {}
}
