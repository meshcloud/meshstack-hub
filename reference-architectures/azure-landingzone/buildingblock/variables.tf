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
    landingzone    = list(object({ key = string, values = list(string) }))
    building_block = list(object({ key = string, values = list(string) }))
    owner_tag_key  = optional(string, "")
  })
  nullable    = false
  description = <<-EOT
  Tags forwarded to the nested integrations, each built in the meshPanel form as a list of {key, values} entries.
  `landingzone` tags are applied to the created landing zones.
  `building_block` tags are applied to the nested building block definitions (budget alert, storage account, spoke network).
  `owner_tag_key` names the landing-zone tag that receives the creator's display name (empty to set none).
  EOT
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
  description = "The user who ordered this architecture, injected by meshStack. Their display name is written to the landing zones' owner tag (see `tags.owner_tag_key`)."
}

# ── Azure platform (existing management group hierarchy is assumed) ──

variable "azure_client_id" {
  type        = string
  nullable    = false
  description = "Client ID of the service principal this run authenticates as. Needs Owner on the management group scope and Microsoft Graph app roles (Application.ReadWrite.All, Directory.Read.All, AppRoleAssignment.ReadWrite.All) to create the management groups, platform service principals and backplane identities."
}

variable "azure_client_secret" {
  type        = string
  nullable    = false
  sensitive   = true
  description = "Client secret of the service principal this run authenticates as. The Azure equivalent of the STACKIT service account key — reused on every run and rotatable from the meshStack UI."
}

variable "azure_tenant_id" {
  type        = string
  nullable    = false
  description = "Azure Entra tenant ID. Used to authenticate the providers and as the ARM tenant for the building block backplanes."
}

# ── Subscription provisioning (a SINGLE_SELECT model + the matching conditional input) ──
# meshStack shows only the block matching the selected model (see the `condition` on each in
# meshstack_integration.tf); main.tf reassembles them into the object modules/azure expects.

variable "subscription_provisioning_model" {
  type        = string
  nullable    = false
  default     = "pre_provisioned"
  description = "How meshStack gets Azure subscriptions: `pre_provisioned` (assign from an existing pool) or `customer_agreement` (create via MCA billing)."

  validation {
    condition     = contains(["pre_provisioned", "customer_agreement"], var.subscription_provisioning_model)
    error_message = "subscription_provisioning_model must be pre_provisioned or customer_agreement."
  }
}

variable "pre_provisioned" {
  type = object({
    unused_subscription_name_prefix = optional(string, "unused-")
  })
  nullable    = false
  default     = { unused_subscription_name_prefix = "unused-" }
  description = "Pre-provisioned model: meshStack assigns subscriptions from existing ones whose name starts with `unused_subscription_name_prefix`."
}

variable "customer_agreement" {
  type = object({
    billing_account_name = string
    billing_profile_name = string
    invoice_section_name = string
  })
  nullable    = true
  default     = null
  description = "Customer-agreement (MCA) model: the billing scope meshStack creates subscriptions under. Required when subscription_provisioning_model is customer_agreement."
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
  description = "Bare GUID of the connectivity subscription where the Azure Hub Network backplane identity lives and, when provision_hub is set, the hub vnet and firewall are created."

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
  Connectivity) this run creates under `parent_management_group_id` (an existing management group or
  the tenant ID), with names prefixed by `name_prefix` to keep them unique across the tenant.
  EOT
}

# ── Foundation — optional Azure-side infra, exposed as toggles that reveal their settings ──

variable "provision_hub" {
  type        = bool
  nullable    = false
  default     = false
  description = "Provision a central hub vnet (via the Azure Hub Network building block) in the connectivity subscription for spoke networks to peer into. When false, spoke networks peer into an existing hub."
}

variable "hub_network" {
  type = object({
    address_space           = optional(string, "10.0.0.0/22")
    hub_vnet_name           = optional(string, "hub-vnet")
    hub_resource_group_name = optional(string, "hub-network")
    create_gateway_subnet   = optional(bool, true)
    deploy_firewall         = optional(bool, false)
    firewall_sku_tier       = optional(string, "Standard")
  })
  nullable    = false
  default     = {}
  description = "Hub vnet settings, used when provision_hub is true. The vnet and resource-group names here are also the ones spoke networks peer into."
}

variable "assign_policies" {
  type        = bool
  nullable    = false
  default     = true
  description = "Assign curated Enterprise-Scale policies to the Corp/Online/Sandbox management groups (Corp locked down, Online region-restricted, Sandbox audit-only)."
}

variable "foundation_resource_groups" {
  type = list(object({
    name     = string
    location = string
  }))
  nullable    = false
  default     = []
  description = "Extra platform-owned resource groups created in the platform subscription."
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
