variable "workspace" {
  type        = string
  nullable    = false
  description = "Identifier of the meshStack workspace that will own the created platform, location and landing zone."
}

variable "use_global_location" {
  type        = bool
  nullable    = false
  description = "Use the global location instead of creating a dedicated location for this platform."
}

variable "otc_domain_name" {
  type        = string
  nullable    = false
  description = "T Cloud Public domain (account) name, e.g. `OTC-EU-DE-00000000001000000000`."
}

variable "otc_region" {
  type        = string
  nullable    = false
  description = "T Cloud Public region tenant projects are created in."

  validation {
    # eu-ch2 runs a separate IAM with its own endpoints and is not covered.
    condition     = contains(["eu-de", "eu-nl"], var.otc_region)
    error_message = "otc_region must be eu-de or eu-nl."
  }
}

variable "otc_access_key" {
  type        = string
  sensitive   = true
  nullable    = false
  description = "Access key of an IAM user in the domain's `admin` group. Used to create the backplane user, its role assignments, the identity provider and the mapping bucket."
}

variable "otc_secret_key" {
  type        = string
  sensitive   = true
  nullable    = false
  description = "Secret key belonging to `otc_access_key`."
}

variable "identity_provider" {
  type = object({
    protocol                    = optional(string)
    name                        = optional(string, "company-idp")
    email_attribute             = optional(string, "email")
    saml_metadata               = optional(string)
    oidc_provider_url           = optional(string)
    oidc_client_id              = optional(string)
    oidc_signing_key            = optional(string)
    oidc_authorization_endpoint = optional(string)
  })
  default     = null
  description = "Company identity provider federated into the domain, as the flat object the meshPanel form produces. Null, or no protocol chosen, skips federation."

  validation {
    condition     = var.identity_provider == null || var.identity_provider.protocol == null || contains(["saml", "oidc"], var.identity_provider.protocol)
    error_message = "identity_provider.protocol must be saml or oidc."
  }

  validation {
    condition = (
      var.identity_provider == null || var.identity_provider.protocol != "oidc" ||
      alltrue([for v in [var.identity_provider.oidc_provider_url, var.identity_provider.oidc_client_id, var.identity_provider.oidc_signing_key] : v != null && v != ""])
    )
    error_message = "The oidc protocol needs the OIDC Issuer URL, Client ID and Signing Keys. Fill them in, or clear the Identity Provider input to skip federation."
  }

  validation {
    condition     = var.identity_provider == null || var.identity_provider.protocol != "saml" || (var.identity_provider.saml_metadata != null && var.identity_provider.saml_metadata != "")
    error_message = "The saml protocol needs the SAML Metadata XML. Fill it in, or clear the Identity Provider input to skip federation."
  }
}

variable "platform_identifier" {
  type        = string
  nullable    = false
  description = "Identifier for the T Cloud Public platform created in meshStack (lowercase letters, digits and dashes only)."

  validation {
    # The backplane IAM user is named `mesh-<identifier>` plus a 7-character playground suffix, and
    # IAM user names are capped at 32 characters.
    condition     = can(regex("^[a-z0-9-]{1,20}$", var.platform_identifier))
    error_message = "platform_identifier must be 1-20 lowercase letters, digits, or dashes."
  }
}

variable "tags" {
  type = object({
    # All optional: the Tags form requires none of them (see meshstack_integration.tf), and a
    # landing zone ordered before the management project existed has no `project` at all.
    landingzone           = optional(list(object({ key = string, values = list(string) })), [])
    building_block        = optional(list(object({ key = string, values = list(string) })), [])
    project               = optional(list(object({ key = string, values = list(string) })), [])
    project_owner_tag_key = optional(string, "")
  })
  nullable    = false
  description = <<-EOT
  Tags forwarded to the nested T Cloud Public integration, each map built in the meshPanel form as a list of {key, values} entries.
  `landingzone` tags are applied to the created landing zone.
  `building_block` tags are applied to the nested building block definitions.
  `project` tags are applied to the management meshProject.
  `project_owner_tag_key` names the tag that receives the creator's display name on the management meshProject (empty to set none).
  EOT
}

variable "payment_method_identifier" {
  type        = string
  default     = null
  description = "Payment method assigned to the management meshProject. Null assigns none."
}

variable "creator" {
  type = object({
    type        = string
    identifier  = string
    displayName = string
    username    = optional(string)
    email       = optional(string)
    euid        = optional(string)
  })
  nullable    = false
  description = "Who ordered the landing zone, injected by meshStack. Their display name is written to the management meshProject's owner tag (see `tags.project_owner_tag_key`)."
}

variable "workspace_members" {
  type = list(object({
    meshIdentifier = string
    username       = string
    firstName      = string
    lastName       = string
    email          = string
    euid           = string
    roles          = list(string)
  }))
  nullable    = false
  description = "Members of the owning workspace, injected by meshStack. Owners and managers become Project Admin of the management project."
}

variable "role_mapping" {
  type        = map(list(string))
  nullable    = false
  description = "Maps each meshStack project role to the T Cloud Public system roles (by role `name`) its project group gets."
}

variable "playground_mode" {
  type        = bool
  nullable    = false
  description = "Deploy a throwaway platform: the platform identifier and the backplane user name get a random suffix so they do not occupy a name for good. Set to false for a platform that is actually used. A playground platform and the building block definition it registers are not meant to be published to other workspaces."
}

variable "hub" {
  type = object({
    git_ref   = optional(string, "main")
    bbd_draft = optional(bool, true)
  })
  const   = true
  default = { git_ref = "main", bbd_draft = true }

  description = <<-EOT
  `git_ref`: meshstack-hub reference used to source the nested T Cloud Public integration. `const` so it can be interpolated into the module source at init time.
  `bbd_draft`: Forwarded as-is to the nested integration's own `hub.bbd_draft`, so its building block definition draft state tracks this building block's own release state.
  EOT
}
