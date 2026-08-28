variable "meshstack_admin_api_key" {
  type        = string
  sensitive   = true
  nullable    = false
  description = "Admin-scoped meshStack API key. Creating a workspace and a payment method needs ADM_* permissions meshStack never grants to a building block's own ephemeral run token, so every meshStack resource here is authenticated with this key/secret pair instead."
}

variable "meshstack_admin_api_secret" {
  type        = string
  sensitive   = true
  nullable    = false
  description = "Admin-scoped meshStack API secret, paired with meshstack_admin_api_key."
}

variable "workspace_identifier" {
  type        = string
  nullable    = false
  description = "Identifier for the new meshStack workspace."
}

variable "workspace_display_name" {
  type        = string
  nullable    = false
  description = "Display name for the new workspace."
}

variable "workspace_expiry_tag_key" {
  type        = string
  nullable    = false
  description = "Tag key the computed expiry date is written under on the new workspace."
}

variable "workspace_ttl_days" {
  type        = number
  nullable    = false
  description = "Number of days after this building block first creates the workspace before it, the payment method, the project and the tenant are destroyed. The module tracks the creation date itself (see time_static.created in main.tf) — this input is a duration, not a date."
}

variable "workspace_owner_username" {
  type        = string
  nullable    = false
  description = "Username granted `workspace_role_name` on the new workspace and `project_role_name` on the new project — one owner for both."
}

variable "workspace_role_name" {
  type        = string
  nullable    = false
  description = "meshStack workspace role granted to `workspace_owner_username`."
}

variable "payment_method_amount" {
  type        = number
  nullable    = false
  description = "Budget amount for the payment method."
}

variable "project_identifier" {
  type        = string
  nullable    = false
  description = "Identifier for the project created inside the new workspace."
}

variable "project_display_name" {
  type        = string
  nullable    = false
  description = "Display name for the project."
}

variable "project_role_name" {
  type        = string
  nullable    = false
  description = "meshStack project role granted to `workspace_owner_username`."
}

variable "platform_ref" {
  type = object({
    uuid = string
    kind = optional(string, "meshPlatform")
  })
  nullable    = false
  description = "Reference (by uuid) to the meshPlatform the tenant is created on."
}

variable "landing_zone_ref" {
  type = object({
    name = string
    kind = optional(string, "meshLandingZone")
  })
  nullable    = false
  description = "Reference to the landing zone the tenant is placed in."
}

variable "tags" {
  type = object({
    workspace      = map(list(string))
    payment_method = map(list(string))
    project        = map(list(string))
  })
  nullable    = false
  description = "Additional tags merged onto the workspace (alongside the mandatory `expiry` tag), the payment method and the project."
}
