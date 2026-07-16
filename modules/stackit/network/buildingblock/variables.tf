variable "service_account_email" {
  type        = string
  nullable    = false
  description = "Email of the STACKIT service account for WIF-based authentication."
}

variable "project_id" {
  type        = string
  nullable    = false
  description = "STACKIT project ID (existing project) in which the network will be created."
}

variable "network_name" {
  type        = string
  nullable    = false
  description = "Name of the STACKIT network."
}

variable "network_prefix_length" {
  type     = number
  default  = 25
  nullable = false

  validation {
    condition     = contains([24, 25, 26, 27, 28], var.network_prefix_length)
    error_message = "network_prefix_length must be one of 24, 25, 26, 27, 28."
  }

  description = "IPv4 prefix length for the network (24-28)."
}

variable "ipv4_nameservers" {
  type        = list(string)
  default     = []
  nullable    = false
  description = "IPv4 nameservers for the network. Empty list falls back to the project's network area default nameservers."
}
