variable "acr_name" {
  type        = string
  nullable    = false
  description = "Name prefix of the Azure Container Registry, alphanumeric only. A random 4-character suffix is appended for global uniqueness."

  validation {
    condition     = can(regex("^[a-zA-Z0-9]{5,46}$", var.acr_name))
    error_message = "ACR name must be 5-46 characters, alphanumeric only (no hyphens or special characters)."
  }
}

variable "resource_group_name" {
  type        = string
  nullable    = false
  description = "Name of the resource group to create for the ACR. It is deleted with the building block."
}

variable "sku" {
  type        = string
  nullable    = false
  description = "SKU tier for the ACR (Basic, Standard, Premium). Premium required for private endpoints."

  validation {
    condition     = contains(["Basic", "Standard", "Premium"], var.sku)
    error_message = "SKU must be Basic, Standard, or Premium."
  }
}

variable "private_endpoint_enabled" {
  type        = bool
  nullable    = false
  description = "Enable private endpoint for ACR (Premium SKU required)"
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

variable "subnet_address_prefix" {
  type        = string
  description = "Address prefix for the private endpoint subnet (only used if subnet_name is not provided)"
  default     = "10.250.1.0/24"

  validation {
    condition     = can(cidrhost(var.subnet_address_prefix, 0))
    error_message = "Subnet address prefix must be a valid CIDR block."
  }
}

variable "subscription_id" {
  type        = string
  nullable    = false
  description = "The Azure subscription the ACR is created in, the tenant's landing zone."
}

variable "location" {
  type        = string
  nullable    = false
  description = "Azure region where resources will be deployed"
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

variable "admin_enabled" {
  type        = bool
  description = "Enable the admin user for basic authentication (not recommended for production). Read its credentials with `az acr credential show`."
  default     = false
}

variable "public_network_access_enabled" {
  type        = bool
  description = "Enable public network access to the ACR"
  default     = true
}

variable "zone_redundancy_enabled" {
  type        = bool
  description = "Enable zone redundancy for the ACR (Premium SKU only, available in select regions)"
  default     = false
}

variable "anonymous_pull_enabled" {
  type        = bool
  description = "Enable anonymous pull access (allows unauthenticated pulls)"
  default     = false
}

variable "data_endpoint_enabled" {
  type        = bool
  description = "Enable dedicated data endpoints (Premium SKU only)"
  default     = false
}

variable "network_rule_bypass_option" {
  type        = string
  description = "Whether to allow trusted Azure services to bypass network rules (AzureServices or None)"
  default     = "AzureServices"

  validation {
    condition     = contains(["AzureServices", "None"], var.network_rule_bypass_option)
    error_message = "Network rule bypass must be AzureServices or None."
  }
}

variable "allowed_ip_ranges" {
  type        = list(string)
  description = "List of IP ranges (CIDR) allowed to access the ACR"
  default     = []
}

variable "retention_days" {
  type        = number
  description = "Number of days to retain untagged manifests (Premium SKU only, 0 to disable)"
  default     = 7

  validation {
    condition     = var.retention_days >= 0 && var.retention_days <= 365
    error_message = "Retention days must be between 0 and 365."
  }
}

variable "trust_policy_enabled" {
  type        = bool
  description = "Enable content trust policy (Premium SKU only)"
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
  description = "Resource group name of the existing VNet. Only used when vnet_name is provided. Defaults to the ACR resource group if not specified."
  default     = null
}

variable "subnet_name" {
  type        = string
  description = "Name of the subnet for private endpoint. If not provided, a new subnet will be created."
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

variable "aks_managed_identity_principal_id" {
  type        = string
  description = "Principal ID of the AKS managed identity to grant AcrPull access. If provided, AcrPull role will be assigned automatically."
  default     = null
}

variable "tags" {
  type        = map(string)
  description = "Tags to apply to all resources"
  default     = {}
}
