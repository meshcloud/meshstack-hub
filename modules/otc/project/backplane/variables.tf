variable "user_name" {
  type        = string
  default     = "mesh-project"
  nullable    = false
  description = "Name of the IAM user the building block authenticates as. Override when deploying several backplanes into one domain."
}

variable "domain_roles" {
  type        = list(string)
  default     = ["secu_admin"]
  nullable    = false
  description = <<-EOT
  Domain-scoped IAM system roles granted to the building block user, by role `name` (not display
  name). `secu_admin` (Security Administrator) covers creating projects, groups, role assignments
  and federation mappings — the only things the building block touches.
  EOT
}

variable "identity_provider" {
  type = object({
    name     = string
    protocol = string

    # SAML: the IdP's metadata XML.
    metadata = optional(string)

    # OIDC: the IdP's issuer, client and signing keys (JWKS JSON).
    oidc = optional(object({
      provider_url           = string
      client_id              = string
      signing_key            = string
      authorization_endpoint = optional(string)
      scopes                 = optional(list(string), ["openid"])
    }))

    # The SAML attribute or OIDC claim that carries the user's email. Project building blocks
    # match meshStack users against it, so it must hold exactly the address meshStack knows.
    email_attribute = optional(string, "email")
  })
  default     = null
  description = <<-EOT
  The customer's identity provider, federated into the domain so meshStack project users log in as
  virtual users. Null skips federation: the building block still creates projects and groups, but
  nobody is mapped into them.
  EOT

  validation {
    condition     = var.identity_provider == null || contains(["saml", "oidc"], var.identity_provider.protocol)
    error_message = "identity_provider.protocol must be `saml` or `oidc`."
  }

  validation {
    condition = var.identity_provider == null || (
      var.identity_provider.protocol == "saml" ? var.identity_provider.metadata != null : var.identity_provider.oidc != null
    )
    error_message = "A `saml` identity provider needs `metadata`, an `oidc` one needs `oidc`."
  }
}
