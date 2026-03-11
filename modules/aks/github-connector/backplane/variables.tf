variable "resource_prefix" {
  type        = string
  default     = "bb-github-connector"
  description = "Prefix used for all named resources created by this backplane (resource group, app registrations, ACR)."
}

variable "aks" {
  type = object({
    cluster_name        = string
    resource_group_name = string
  })
  description = "Reference to the existing AKS cluster this building block connects to."
}

variable "acr" {
  type = object({
    location            = string
    resource_group_name = optional(string)
  })
  description = "Configuration for the shared Azure Container Registry. resource_group_name defaults to the resource group created by this backplane when omitted."
  default = {
    location            = "Germany West Central"
    resource_group_name = null
  }
}

