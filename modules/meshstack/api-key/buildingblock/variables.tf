variable "owned_by_workspace" {
  type        = string
  nullable    = false
  description = "Identifier of the meshStack workspace that owns the API key. The key can only act within this workspace."
}

variable "display_name" {
  type        = string
  nullable    = false
  description = "Display name of the API key, shown in meshPanel and used to tell keys apart."
}

variable "permissions" {
  type        = set(string)
  nullable    = false
  description = "Workspace permissions granted to the API key (e.g. `PROJECT_LIST`, `TENANT_LIST`). Must be a subset of the permissions the run token itself holds — see the definition's grantable permission list."

  validation {
    condition     = length(var.permissions) > 0
    error_message = "The API key must be granted at least one permission."
  }
}

variable "expires_at" {
  type        = string
  nullable    = true
  default     = null
  description = "Optional expiry date of the API key as an ISO date (e.g. `2025-12-31`). If null the key never expires; setting an expiry is recommended."
}
