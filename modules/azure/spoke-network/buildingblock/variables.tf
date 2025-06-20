variable "hub_rg" {
  description = "value"
}

variable "hub_vnet" {
}

variable "location" {
}

variable "name" {
  description = "name of the virtual spoke network. This name is used as the basis to generate resource names for vnets and peerings."
  type        = string
}

variable "spoke_rg_name" {
  default     = "connectivity"
  type        = string
  description = "name of the resource group to deploy for hosting the spoke vnet"
}

variable "address_space" {
  type        = string
  description = "Address space of the virtual network in CIDR notation"
}

# this variable is supposed to be used by an injected config.tf file for configuring the azurerm provider
# tflint-ignore: terraform_unused_declarations
variable "subscription_id" {
  type        = string
  description = "The ID of the subscription that you want to deploy the spoke to"
}

variable "spoke_owner_principal_id" {
  type        = string
  description = "Principal id that will become owner of the spokes. Defaults to the client_id of the spoke azurerm provider."
  default     = null
}

variable "azure_delay_seconds" {
  type        = number
  description = "Number of additional seconds to wait between Azure API operations to mitigate eventual consistency issues in order to increase automation reliabilty."
  default     = 30
}