# ── Backplane inputs (static, set once per building block definition) ──────────

variable "project_id" {
  type        = string
  nullable    = false
  description = "STACKIT project ID of the application team's tenant (injected from PLATFORM_TENANT_ID)."
}

variable "organization_id" {
  type        = string
  nullable    = false
  description = "STACKIT organization ID."
}

variable "network_area_id" {
  type        = string
  nullable    = false
  description = "STACKIT network area ID of the platform hub. The spoke network will be attached to this area."
}

variable "firewall_next_hop_ip" {
  type        = string
  default     = null
  description = "IPv4 address of the firewall next-hop. When set, creates a routing table with a 0.0.0.0/0 default route via this address."
}

# ── User inputs (set per building block instance) ─────────────────────────────

variable "network_prefix_length" {
  type        = number
  default     = 25
  nullable    = false
  description = "IPv4 prefix length for the spoke network (24–28). Controls subnet size: /24 = 254 hosts, /25 = 126, /26 = 62, /27 = 30, /28 = 14."

  validation {
    condition     = var.network_prefix_length >= 24 && var.network_prefix_length <= 28
    error_message = "network_prefix_length must be between 24 and 28 (inclusive)."
  }
}

variable "ipv4_nameservers" {
  type        = string
  default     = null
  nullable    = true
  description = "Comma-separated list of IPv4 DNS nameservers, e.g. '8.8.8.8,8.8.4.4'. Leave null to use STACKIT defaults."
}
