variable "name" {
  type        = string
  nullable    = false
  description = "Name for the building block identity and role definition."
  validation {
    condition     = can(regex("^[-a-z0-9]+$", var.name))
    error_message = "Only alphanumeric lowercase characters and dashes are allowed"
  }
}

variable "scope" {
  type        = string
  nullable    = false
  description = "Scope for role assignment (management group or subscription ID)."
}

variable "location" {
  type        = string
  nullable    = false
  description = "Azure region for the UAMI resource."
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
