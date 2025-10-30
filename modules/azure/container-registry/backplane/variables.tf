variable "name" {
  type        = string
  nullable    = false
  description = "name of the building block, used for naming resources"
  default     = "container-registry"
  validation {
    condition     = can(regex("^[-a-z0-9]+$", var.name))
    error_message = "Only alphanumeric lowercase characters and dashes are allowed"
  }
}

variable "scope" {
  type        = string
  nullable    = false
  description = "Scope where the building block should be deployable, typically the parent of all Landing Zones."
}

variable "hub_scope" {
  type        = string
  nullable    = false
  description = "Scope of the hub subscription where VNet peering will be created (typically a different subscription than 'scope')"
}

variable "existing_principal_ids" {
  type        = set(string)
  default     = []
  description = "set of existing principal ids that will be granted permissions to deploy the building block"
}

variable "existing_hub_principal_ids" {
  type        = set(string)
  default     = []
  description = "set of existing principal ids that will be granted permissions to peer with the hub VNet"
}

variable "create_service_principal_name" {
  type        = string
  default     = null
  description = "name of a service principal to create and grant permissions to deploy the building block"

  validation {
    condition     = var.create_service_principal_name == null ? true : can(regex("^[-a-zA-Z0-9_]+$", var.create_service_principal_name))
    error_message = "Service principal name can only contain alphanumeric characters, hyphens, and underscores"
  }
}

variable "create_hub_service_principal_name" {
  type        = string
  default     = null
  description = "name of a separate service principal to create for hub VNet peering (least privilege)"

  validation {
    condition     = var.create_hub_service_principal_name == null ? true : can(regex("^[-a-zA-Z0-9_]+$", var.create_hub_service_principal_name))
    error_message = "Service principal name can only contain alphanumeric characters, hyphens, and underscores"
  }
}

variable "workload_identity_federation" {
  type = object({
    issuer  = string
    subject = string
  })
  default     = null
  description = "Configuration for workload identity federation. If not provided, an application password will be created instead."
}

variable "hub_workload_identity_federation" {
  type = object({
    issuer  = string
    subject = string
  })
  default     = null
  description = "Configuration for workload identity federation for hub service principal. If not provided, an application password will be created instead."
}
