variable "meshstack_admin_api_key" {
  type        = string
  sensitive   = true
  nullable    = false
  description = "Admin-scoped meshStack API key. Creating a workspace and a payment method needs ADM_* permissions meshStack never grants to a building block's own ephemeral run token, so every resource here is managed through an aliased provider authenticated with this key/secret pair instead."
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
  description = "Tag key `workspace_expiry_date` is written under on the new workspace."
}

variable "workspace_expiry_date" {
  type        = string
  nullable    = false
  description = "Expiry date (YYYY-MM-DD) written to the workspace's `workspace_expiry_tag_key` tag."
}

variable "workspace_owner_username" {
  type        = string
  nullable    = false
  description = "Username granted `workspace_role_name` on the new workspace."
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

variable "payment_method_expiration_date" {
  type        = string
  nullable    = false
  description = "Expiration date (YYYY-MM-DD) of the payment method itself, independent of the workspace's `expiry` tag. Empty string means no expiration."
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

variable "project_admin_username" {
  type        = string
  nullable    = false
  description = "Username granted `project_role_name` on the new project."
}

variable "project_role_name" {
  type        = string
  nullable    = false
  description = "meshStack project role granted to `project_admin_username`."
}

variable "platform_ref" {
  type = object({
    uuid = string
    kind = string
  })
  nullable    = false
  description = "Reference (by uuid) to the STACKIT meshPlatform the tenant is created on."
}

variable "landing_zone_ref" {
  type = object({
    name = string
    kind = string
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
