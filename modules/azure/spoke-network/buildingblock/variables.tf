variable "hub_rg" {
  type        = string
  description = "Name of the resource group that contains the hub vnet to peer into."
}

variable "hub_vnet" {
  type        = string
  description = "Name of the hub vnet to peer the spoke into."
}

variable "hub_subscription_id" {
  type        = string
  description = "The ID of the subscription that hosts the hub vnet."
}

variable "location" {
  type        = string
  description = "Azure region where the spoke resource group and vnet are created."
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
  default     = null
  description = "Address space of the virtual network in CIDR notation. Set either this or `ipam_pool_id`."
}

variable "ipam_pool_id" {
  type        = string
  default     = null
  description = "Resource ID of an Azure Virtual Network Manager IPAM pool to draw the address space from. Set either this or `address_space`."
}

variable "ipam_prefix_length" {
  type        = number
  default     = 24
  description = "Prefix length of the address space drawn from `ipam_pool_id`, e.g. 24 for a /24."

  validation {
    condition     = var.ipam_prefix_length >= 16 && var.ipam_prefix_length <= 29
    error_message = "Prefix length must be between 16 and 29."
  }
}

variable "subscription_id" {
  type        = string
  description = "The ID of the subscription that you want to deploy the spoke to (used by the spoke azurerm provider)."
}

variable "spoke_owner_principal_id" {
  type        = string
  description = "Principal id that will become owner of the spokes. Defaults to the client_id of the spoke azurerm provider."
  default     = null
}