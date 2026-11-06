variable "name" {
  type        = string
  nullable    = false
  description = "Name for the building block identity, resource group and role definitions."
  validation {
    condition     = can(regex("^[-a-z0-9]+$", var.name))
    error_message = "Only alphanumeric lowercase characters and dashes are allowed"
  }
}

variable "scope" {
  type        = string
  nullable    = false
  description = "Scope where the spoke network can be deployed (management group or subscription ID), typically the parent of all landing zones."
}

variable "hub_scope" {
  type        = string
  nullable    = false
  description = "Scope where the hub vnet lives (management group or subscription ID). The identity is granted vnet peering permissions here so it can peer the spoke into the hub."
}

variable "subscription_id" {
  type        = string
  nullable    = false
  description = "Subscription (bare GUID) where the UAMI and its resource group are created. Typically the hub subscription so the identity lives in a stable, platform-owned place. Deploy the backplane once per hub environment (e.g. hub-dev, hub-prod) with the respective subscription."

  validation {
    condition     = can(regex("^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$", var.subscription_id))
    error_message = "Must be a bare subscription GUID, not a '/subscriptions/<guid>' path."
  }
}

variable "location" {
  type        = string
  nullable    = false
  description = "Azure region for the UAMI resource group."
}

variable "workload_identity_federations" {
  type = list(object({
    issuer   = string
    audience = string
    subject  = string
  }))
  nullable    = false
  description = <<-EOT
  meshStack identities the automation identity trusts, one per building block runner. For more
  subjects of one issuer, pass one entry per subject.
  EOT

  validation {
    condition     = length(var.workload_identity_federations) > 0
    error_message = "The automation identity needs at least one identity to trust."
  }

  validation {
    condition     = alltrue([for identity in var.workload_identity_federations : identity.subject != null])
    error_message = "These identities need a subject: ${join(", ", [for identity in var.workload_identity_federations : identity.issuer if identity.subject == null])}."
  }
}
