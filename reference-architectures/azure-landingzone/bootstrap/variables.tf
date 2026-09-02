variable "name" {
  type        = string
  nullable    = false
  default     = "azure-landingzone-bootstrap"
  description = "Name for the bootstrap identity and its resource group. Must match pattern ^[-a-z0-9]+$."
  validation {
    condition     = can(regex("^[-a-z0-9]+$", var.name))
    error_message = "Only alphanumeric lowercase characters and dashes are allowed"
  }
}

variable "scope" {
  type        = string
  nullable    = false
  description = "Where the bootstrap identity is granted Owner — high enough to cover everything the architecture provisions. Accepts a bare management group name (e.g. `flo-test-ref-arch` or the tenant ID), a bare subscription GUID, or a full resource path. Typically the tenant root / a top management group."
}

variable "subscription_id" {
  type        = string
  nullable    = false
  description = "Subscription (bare GUID) where the bootstrap identity and its resource group are created."

  validation {
    condition     = can(regex("^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$", var.subscription_id))
    error_message = "Must be a bare subscription GUID, not a '/subscriptions/<guid>' path."
  }
}

variable "location" {
  type        = string
  nullable    = false
  description = "Azure region for the bootstrap identity's resource group."
}

variable "management_group_name_prefix" {
  type        = string
  nullable    = false
  default     = ""
  description = "Prefix for the created management group names/IDs (e.g. 'flotest-az-'), to keep them unique across the tenant. Must match the prefix the building block uses so it can import them."
}

variable "workload_identity_federation" {
  type = object({
    issuer   = string
    subjects = list(string)
  })
  nullable    = false
  description = "WIF issuer and subjects for federated authentication of the bootstrap identity. The subject binds the identity to the reference architecture's building block definition."
}
