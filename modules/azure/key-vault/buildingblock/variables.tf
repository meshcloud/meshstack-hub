variable "key_vault_name" {
  type        = string
  nullable    = false
  description = "The name of the key vault."
}

variable "key_vault_resource_group_name" {
  type        = string
  nullable    = false
  description = "The name of the resource group containing the key vault."
}

variable "location" {
  type        = string
  description = "The location/region where the key vault is created."
}

variable "public_network_access_enabled" {
  type    = bool
  default = false
}

variable "private_endpoint_enabled" {
  type        = bool
  description = "Enable private endpoint for Key Vault"
  default     = false
}

variable "private_dns_zone_id" {
  type        = string
  description = "Private DNS Zone ID for private endpoint. Use 'System' for Azure-managed zone, or provide custom zone ID. Only used when private_endpoint_enabled is true."
  default     = "System"
}

variable "vnet_name" {
  type        = string
  description = "Name of the virtual network for private endpoint. If not provided, a new VNet will be created."
  default     = null
}

variable "existing_vnet_resource_group_name" {
  type        = string
  description = "Resource group name of the existing VNet. Only used when vnet_name is provided. Defaults to the Key Vault resource group if not specified."
  default     = null
}

variable "vnet_address_space" {
  type        = string
  description = "Address space for the VNet (only used if vnet_name is not provided)"
  default     = "10.250.0.0/16"

  validation {
    condition     = can(cidrhost(var.vnet_address_space, 0))
    error_message = "VNet address space must be a valid CIDR block."
  }
}

variable "subnet_name" {
  type        = string
  description = "Name of the subnet for private endpoint. If not provided, a new subnet will be created."
  default     = null
}

variable "subnet_address_prefix" {
  type        = string
  description = "Address prefix for the private endpoint subnet (only used if subnet_name is not provided)"
  default     = "10.250.1.0/24"

  validation {
    condition     = can(cidrhost(var.subnet_address_prefix, 0))
    error_message = "Subnet address prefix must be a valid CIDR block."
  }
}

variable "hub_subscription_id" {
  type        = string
  description = "Subscription ID of the hub network. Required when private_endpoint_enabled is true and connecting to a hub."
  default     = null
}

variable "hub_resource_group_name" {
  type        = string
  description = "Resource group name of the hub virtual network. Required when private_endpoint_enabled is true and connecting to a hub."
  default     = null
}

variable "hub_vnet_name" {
  type        = string
  description = "Name of the hub virtual network to peer with. Required when private_endpoint_enabled is true and connecting to a hub."
  default     = null
}

variable "use_remote_gateways" {
  type        = bool
  description = "Use remote gateways from hub VNet. Set to true only if hub has a VPN/ExpressRoute gateway configured."
  default     = false
}

variable "allow_gateway_transit_from_hub" {
  type        = bool
  description = "Allow gateway transit from hub to spoke. Set to true if hub has a gateway and you want spoke to use it."
  default     = false
}

variable "tags" {
  type        = map(string)
  description = "Tags to apply to all resources"
  default     = {}
}
