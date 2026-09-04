variable "workspace" {
  type        = string
  nullable    = false
  description = "Identifier of the meshStack workspace that will own the created platform, location, landing zones and building block definitions."
}

variable "use_global_location" {
  type        = bool
  nullable    = false
  description = "Use the global meshStack location instead of creating a dedicated location for this platform."
}

variable "platform_identifier" {
  type        = string
  nullable    = false
  description = "Identifier for the Azure platform created in meshStack (letters, digits and dashes only). Landing zone names are derived as `<platform_identifier>-<archetype>`."

  validation {
    condition     = can(regex("^[a-zA-Z0-9-]+$", var.platform_identifier))
    error_message = "platform_identifier must only contain letters, digits, and dashes."
  }
}

variable "playground_mode" {
  type        = bool
  nullable    = false
  description = "Deploy a throwaway platform: the platform identifier gets a random suffix so it does not occupy a name for good across the meshStack instance. Set to false for a platform that is actually used. A playground platform and the building block definitions it registers are not meant to be published to other workspaces."
}

variable "tags" {
  type = object({
    landingzone    = map(list(string))
    building_block = map(list(string))
  })
  nullable    = false
  description = <<-EOT
  Tags forwarded to the nested integrations.
  `landingzone` tags are applied to the created landing zones.
  `building_block` tags are applied to the nested building block definitions (budget alert, storage account, spoke network).
  EOT
}

# ── Azure platform (existing management group hierarchy is assumed) ──

variable "azure_tenant_id" {
  type        = string
  nullable    = false
  description = "Azure Entra tenant ID. Used as the ARM tenant for the building block backplanes."
}

variable "azure_subscription_provisioning" {
  type = object({
    pre_provisioned = optional(object({
      unused_subscription_name_prefix = optional(string, "unused-")
    }))
    customer_agreement = optional(object({
      billing_account_name = string
      billing_profile_name = string
      invoice_section_name = string
    }))
  })
  nullable    = false
  default     = { pre_provisioned = {} }
  description = <<-EOT
  Azure subscription provisioning model — set exactly one:
  `pre_provisioned` (default): meshStack assigns subscriptions from a pool of existing ones whose name starts with `unused_subscription_name_prefix` (default `unused-`). No MCA service principal is created.
  `customer_agreement`: meshStack creates subscriptions via the given MCA billing scope.
  EOT

  validation {
    condition     = (var.azure_subscription_provisioning.pre_provisioned != null) != (var.azure_subscription_provisioning.customer_agreement != null)
    error_message = "Set exactly one of pre_provisioned or customer_agreement."
  }
}

variable "azure_subscription_owner_object_ids" {
  type        = list(string)
  default     = null
  description = "Optional explicit subscription owner object IDs. If null, the applying principal is used."
}

variable "azure_location" {
  type        = string
  nullable    = false
  default     = "germanywestcentral"
  description = "Azure region where the building block backplane resource groups and identities are created."
}

# ── Building block target/backplane placement ──

variable "azure_platform_subscription_id" {
  type        = string
  nullable    = false
  description = "Bare GUID of a platform-owned subscription. The azurerm provider targets it, the budget-alert and storage-account backplanes are created in it, and (as written) those two building blocks deploy their resources into it."

  validation {
    condition     = can(regex("^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$", var.azure_platform_subscription_id))
    error_message = "azure_platform_subscription_id must be a bare subscription GUID, not a '/subscriptions/<guid>' path."
  }
}

# ── Spoke network hub (existing central hub is assumed) ──

variable "azure_connectivity_subscription_id" {
  type        = string
  nullable    = false
  description = "Bare GUID of the connectivity subscription where the Azure Hub Network backplane identity lives and, when foundation.hub is set, the hub vnet and firewall are created."

  validation {
    condition     = can(regex("^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$", var.azure_connectivity_subscription_id))
    error_message = "azure_connectivity_subscription_id must be a bare subscription GUID, not a '/subscriptions/<guid>' path."
  }
}

variable "azure_management_groups" {
  type = object({
    parent_management_group_id = string
    name_prefix                = optional(string, "")
    landing_zones_display_name = optional(string, "Landing Zones")
    corp_display_name          = optional(string, "Corp")
    online_display_name        = optional(string, "Online")
    sandbox_display_name       = optional(string, "Sandbox")
    connectivity_display_name  = optional(string, "Connectivity")
  })
  nullable    = false
  description = <<-EOT
  Enterprise-Scale management group hierarchy (Landing Zones → Corp/Online/Sandbox, plus
  Connectivity) under `parent_management_group_id`, with names prefixed by `name_prefix`. The
  bootstrap step already created these; this building block adopts them via `import` blocks and
  manages them. Pre-configured STATIC by the platform team at registration (parent = bootstrap scope,
  same name_prefix as the bootstrap) — end users don't specify it.
  EOT
}

variable "foundation" {
  type = object({
    hub = optional(object({
      address_space           = optional(string, "10.0.0.0/22")
      hub_vnet_name           = optional(string, "hub-vnet")
      hub_resource_group_name = optional(string, "hub-network")
      create_gateway_subnet   = optional(bool, true)
      deploy_firewall         = optional(bool, false)
      firewall_sku_tier       = optional(string, "Standard")
    }))
    policies        = optional(bool, false)
    resource_groups = optional(map(object({ location = string })), {})
  })
  default     = null
  description = <<-EOT
  Optional Azure-side foundation this architecture provisions on top of the meshStack wiring. Leave
  null to only register the platform, landing zones and building blocks. (The management group
  hierarchy is configured separately via `azure_management_groups`.)
  `hub`: when set, orders one Azure Hub Network instance — a hub vnet (with optional firewall) in the
  connectivity subscription — that spoke networks peer into. The Azure Hub Network building block
  itself is always registered.
  `policies`: when true, assigns curated Enterprise-Scale policies to the Corp/Online/Sandbox
  management groups.
  `resource_groups`: extra platform-owned resource groups (name => { location }) created in the
  platform subscription.
  EOT
}

variable "azure_backplane_subscription_id" {
  type        = string
  default     = null
  description = "Optional bare GUID of the subscription where the spoke-network backplane identity is created. Defaults to azure_platform_subscription_id. Typically the hub subscription so the automation identity lives in a stable, platform-owned place."

  validation {
    condition     = var.azure_backplane_subscription_id == null || can(regex("^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$", var.azure_backplane_subscription_id))
    error_message = "azure_backplane_subscription_id must be a bare subscription GUID, not a '/subscriptions/<guid>' path."
  }
}

variable "hub" {
  type = object({
    git_ref   = optional(string, "main")
    bbd_draft = optional(bool, true)
  })
  const   = true
  default = { git_ref = "main", bbd_draft = true }

  description = <<-EOT
  `git_ref`: meshstack-hub reference used to source the nested platform, budget-alert, storage-account and spoke-network integration modules. `const` so it can be interpolated into the module source at init time.
  `bbd_draft`: Forwarded as-is to those nested integrations' own `hub.bbd_draft`, so their building block definition draft state tracks this architecture's own release state.
  EOT
}
