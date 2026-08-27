variable "subscription_id" {
  type        = string
  description = "The Azure subscription ID where the resource group will be created."
}

variable "workspace_identifier" {
  type        = string
  description = "The meshStack workspace identifier. Used to generate the resource group name."
}

variable "project_identifier" {
  type        = string
  description = "The meshStack project identifier. Used to generate the resource group name."
}

variable "location" {
  type        = string
  description = "The Azure region where the resource group will be created (e.g. 'westeurope', 'eastus')."
  default     = "westeurope"
}
