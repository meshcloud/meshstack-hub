variable "parent_management_group_id" {
  type        = string
  nullable    = false
  description = "Parent management group under which the hierarchy is created — a bare management group name (e.g. the tenant ID for the tenant root group) or a full '/providers/Microsoft.Management/managementGroups/<id>' path."
}

variable "name_prefix" {
  type        = string
  nullable    = false
  default     = ""
  description = "Prefix for the created management group names (IDs), e.g. '<platform_identifier>-', to keep them unique across the tenant. Must be known at plan time (do not derive it from apply-time values like a random suffix)."
}

variable "landing_zones_display_name" {
  type        = string
  nullable    = false
  default     = "Landing Zones"
  description = "Display name of the parent management group that holds the archetype groups."
}

variable "corp_display_name" {
  type        = string
  nullable    = false
  default     = "Corp"
  description = "Display name of the Corp management group."
}

variable "online_display_name" {
  type        = string
  nullable    = false
  default     = "Online"
  description = "Display name of the Online management group."
}

variable "sandbox_display_name" {
  type        = string
  nullable    = false
  default     = "Sandbox"
  description = "Display name of the Sandbox management group."
}

variable "connectivity_display_name" {
  type        = string
  nullable    = false
  default     = "Connectivity"
  description = "Display name of the Connectivity management group that hosts the hub subscription."
}
