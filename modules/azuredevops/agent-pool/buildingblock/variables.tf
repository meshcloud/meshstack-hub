variable "pat_secret_name" {
  default     = "azure-devops-pat"
  description = "Name of the Azure DevOps PAT Token stored in the KeyVault"
  sensitive   = true
  type        = string
}

variable "azure_devops_organization_url" {
  description = "Azure DevOps organization URL (e.g., https://dev.azure.com/myorg)"
  type        = string
}

variable "key_vault_name" {
  description = "Name of the Key Vault containing the Azure DevOps PAT"
  type        = string
}

variable "resource_group_name" {
  description = "Resource group name containing the Key Vault"
  type        = string
}

variable "agent_pool_name" {
  description = "Name of the Azure DevOps agent pool"
  type        = string

  validation {
    condition     = length(var.agent_pool_name) > 0 && length(var.agent_pool_name) <= 64
    error_message = "Agent pool name must be between 1 and 64 characters."
  }
}

variable "vmss_name" {
  description = "Name of the existing Azure Virtual Machine Scale Set"
  type        = string
}

variable "vmss_resource_group_name" {
  description = "Resource group name containing the VMSS"
  type        = string
}

variable "service_endpoint_id" {
  description = "ID of the Azure service connection for the elastic pool"
  type        = string
}

variable "service_endpoint_scope" {
  description = "Project ID where the service endpoint is defined"
  type        = string
}

variable "auto_provision" {
  description = "Automatically provision projects with this agent pool"
  type        = bool
  default     = false
}

variable "auto_update" {
  description = "Automatically update agents in this pool"
  type        = bool
  default     = true
}

variable "max_capacity" {
  description = "Maximum number of virtual machines in the scale set"
  type        = number
  default     = 10

  validation {
    condition     = var.max_capacity > 0 && var.max_capacity <= 1000
    error_message = "Max capacity must be between 1 and 1000."
  }
}

variable "desired_idle" {
  description = "Number of agents to keep idle and ready to run jobs"
  type        = number
  default     = 1

  validation {
    condition     = var.desired_idle >= 0
    error_message = "Desired idle must be 0 or greater."
  }
}

variable "recycle_after_each_use" {
  description = "Tear down the virtual machine after each use"
  type        = bool
  default     = false
}

variable "max_saved_node_count" {
  description = "Maximum number of machines to keep in the pool"
  type        = number
  default     = 0

  validation {
    condition     = var.max_saved_node_count >= 0
    error_message = "Max saved node count must be 0 or greater."
  }
}

variable "time_to_live_minutes" {
  description = "Time in minutes to keep idle agents before removing them"
  type        = number
  default     = 30

  validation {
    condition     = var.time_to_live_minutes >= 0
    error_message = "Time to live must be 0 or greater."
  }
}

variable "agent_interactive_ui" {
  description = "Enable agents to run with interactive UI"
  type        = bool
  default     = false
}

variable "desired_size" {
  description = "Initial size of the elastic pool"
  type        = number
  default     = 1

  validation {
    condition     = var.desired_size >= 0
    error_message = "Desired size must be 0 or greater."
  }
}

variable "project_id" {
  description = "Azure DevOps project ID to authorize the agent pool (optional)"
  type        = string
  default     = null
}

variable "users" {
  description = "List of users from authoritative system"
  type = list(object({
    meshIdentifier = string
    username       = string
    firstName      = string
    lastName       = string
    email          = string
    euid           = string
    roles          = list(string)
  }))
  default = []
}
