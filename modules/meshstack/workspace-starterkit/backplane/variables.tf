variable "meshstack_workspace_identifier" {
  type        = string
  nullable    = false
  description = "Identifier of the meshStack workspace that owns the API key. The key's permissions are admin-scoped, so this decides who administers the key, not what it can reach."
}

variable "api_key_display_name" {
  type        = string
  nullable    = false
  default     = "meshstack-workspace-starterkit"
  description = "Display name of the API key, as it appears in the owning workspace's API key list. Give each deployment its own name if an instance runs several flavours of this starterkit."
}

variable "api_key_lifetime_days" {
  type        = number
  nullable    = false
  default     = 90
  description = "How long the API key is valid. meshStack requires an expiry and caps how far out it may sit, so this cannot be turned off — an instance that caps it lower than this answers the apply with a 409 naming its maximum. The expiry rolls forward on the first apply past half this many days, so a deployment applying at least that often keeps the key alive; past the expiry every run of this building block fails to authenticate, cleanup runs included."

  validation {
    condition     = var.api_key_lifetime_days >= 2
    error_message = "api_key_lifetime_days must be at least 2: the expiry rolls forward at half the lifetime, and a rotation window is measured in whole days."
  }
}

variable "additional_api_key_permissions" {
  type        = list(string)
  nullable    = false
  default     = []
  description = "Permissions to add to the ones the building block is known to need (see the `permissions` local in main.tf). An escape hatch for an instance whose configuration needs more — e.g. `ADM_USER_LIST` where resolving the owner's username requires it — so a deployment is not blocked on a hub release."
}
