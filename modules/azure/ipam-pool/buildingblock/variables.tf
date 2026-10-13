variable "subscription_id" {
  type        = string
  description = "The ID of the subscription that hosts the network manager and its IPAM pool."
}

variable "location" {
  type        = string
  description = "Azure region where the resource group, network manager and IPAM pool are created."
}

variable "resource_group_name" {
  type        = string
  default     = "ipam"
  description = "Name of the resource group created to host the network manager and its IPAM pool."
}

variable "name" {
  type        = string
  description = "Name of the IPAM pool. Also the basis for the network manager name."

  validation {
    condition     = can(regex("^[a-z0-9][-a-z0-9]{1,40}$", var.name))
    error_message = "Only lowercase letters, numbers and dashes are allowed (2–41 characters, must start with a letter or number)."
  }
}

variable "address_prefix" {
  type        = string
  description = "Address range of the pool in CIDR notation, e.g. '10.100.0.0/16'. Spoke networks are carved out of this range."

  validation {
    condition     = can(cidrhost(var.address_prefix, 0))
    error_message = "Must be a valid CIDR range, e.g. '10.100.0.0/16'."
  }
}

variable "network_manager_scope" {
  type        = string
  description = "Management group ('/providers/Microsoft.Management/managementGroups/<id>') or subscription ('/subscriptions/<guid>') the network manager governs. Only virtual networks inside this scope can draw address space from the pool."

  validation {
    condition     = can(regex("^/subscriptions/[0-9a-fA-F-]{36}$|^/providers/Microsoft\\.Management/managementGroups/.+$", var.network_manager_scope))
    error_message = "Must be a full resource path: '/subscriptions/<guid>' or '/providers/Microsoft.Management/managementGroups/<id>'."
  }
}
