variable "hub_resource_group_name" {
  type        = string
  nullable    = false
  default     = "hub-network"
  description = "Name of the resource group created in the connectivity subscription to host the hub vnet and firewall."
}

variable "hub_vnet_name" {
  type        = string
  nullable    = false
  default     = "hub-vnet"
  description = "Name of the central hub virtual network. Used as the basis for the firewall and route table resource names."
}

variable "address_space" {
  type        = string
  nullable    = false
  description = "Address space of the hub virtual network in CIDR notation, e.g. '10.0.0.0/22'. Must be large enough for the derived AzureFirewallSubnet and GatewaySubnet (a /22 gives four /24s)."

  validation {
    condition     = can(regex("^([0-9]{1,3}\\.){3}[0-9]{1,3}/[0-9]{1,2}$", var.address_space))
    error_message = "Address space must be a valid IPv4 CIDR range, e.g. '10.0.0.0/22'."
  }
}

variable "location" {
  type        = string
  nullable    = false
  default     = "germanywestcentral"
  description = "Azure region where the hub resource group, vnet and firewall are created."
}

variable "create_gateway_subnet" {
  type        = bool
  nullable    = false
  default     = true
  description = "Create a GatewaySubnet for a future VPN/ExpressRoute gateway."
}

variable "deploy_firewall" {
  type        = bool
  nullable    = false
  default     = false
  description = "Deploy an Azure Firewall into the hub, with an AzureFirewallSubnet, a static public IP and an egress route table with a default route pointing at the firewall."
}

variable "firewall_sku_tier" {
  type        = string
  nullable    = false
  default     = "Standard"
  description = "Azure Firewall SKU tier. Only Standard and Premium are supported (Basic requires a separate management subnet and IP)."

  validation {
    condition     = contains(["Standard", "Premium"], var.firewall_sku_tier)
    error_message = "firewall_sku_tier must be 'Standard' or 'Premium'."
  }
}

variable "firewall_threat_intel_mode" {
  type        = string
  nullable    = false
  default     = "Alert"
  description = "Azure Firewall threat intelligence mode: Off, Alert or Deny."

  validation {
    condition     = contains(["Off", "Alert", "Deny"], var.firewall_threat_intel_mode)
    error_message = "firewall_threat_intel_mode must be 'Off', 'Alert' or 'Deny'."
  }
}
