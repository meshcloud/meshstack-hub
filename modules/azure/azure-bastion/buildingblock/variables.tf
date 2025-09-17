variable "name" {
  description = "Name of the Azure Bastion deployment"
  type        = string
}

variable "location" {
  description = "Azure region where resources will be deployed"
  type        = string
}

variable "resource_group_name" {
  description = "Name of the resource group where Bastion will be deployed"
  type        = string
}

variable "vnet_name" {
  description = "Name of the virtual network where Bastion subnet will be created"
  type        = string
}



variable "bastion_subnet_cidr" {
  description = "CIDR block for the AzureBastionSubnet (minimum /27)"
  type        = string
  validation {
    condition     = can(cidrhost(var.bastion_subnet_cidr, 0))
    error_message = "The bastion_subnet_cidr must be a valid CIDR block."
  }
}

variable "bastion_sku" {
  description = "SKU of the Azure Bastion Host"
  type        = string
  default     = "Basic"
  validation {
    condition     = contains(["Basic", "Standard"], var.bastion_sku)
    error_message = "The bastion_sku must be either 'Basic' or 'Standard'."
  }
}

variable "enable_resource_locks" {
  description = "Enable resource locks to prevent accidental deletion/modification"
  type        = bool
  default     = true
}

variable "azure_delay_seconds" {
  description = "Delay in seconds to wait for Azure resources to be ready"
  type        = number
  default     = 30
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}

variable "enable_observability" {
  description = "Enable comprehensive observability (alerts, monitoring)"
  type        = bool
  default     = true
}

variable "alert_email_receivers" {
  description = "List of email receivers for alerts"
  type = list(object({
    name  = string
    email = string
  }))
  default = []
}

variable "alert_webhook_receivers" {
  description = "List of webhook receivers for alerts (Teams, Slack, etc.)"
  type = list(object({
    name = string
    uri  = string
  }))
  default = []
}