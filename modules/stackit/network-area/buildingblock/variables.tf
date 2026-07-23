variable "organization_id" {
  type        = string
  nullable    = false
  description = "STACKIT organization ID under which the network area will be created."
}

variable "service_account_email" {
  type        = string
  nullable    = false
  description = "Email of the STACKIT service account for WIF-based authentication."
}

variable "network_area_name" {
  type        = string
  nullable    = false
  description = "Name of the STACKIT network area."
}

variable "network_ranges" {
  type        = list(string)
  nullable    = false
  description = "List of IPv4 CIDR ranges available to projects within the network area."
}

variable "transfer_network" {
  type        = string
  nullable    = false
  description = "IPv4 CIDR range used as the transfer network between the network area and connected networks."
}

variable "min_prefix_length" {
  type        = number
  nullable    = false
  description = "Minimum prefix length allowed for networks created within the network area."
}

variable "max_prefix_length" {
  type        = number
  nullable    = false
  description = "Maximum prefix length allowed for networks created within the network area."
}

variable "default_prefix_length" {
  type        = number
  nullable    = false
  description = "Default prefix length used for networks created within the network area when none is specified."
}

variable "default_nameservers" {
  type        = list(string)
  nullable    = false
  description = "Default IPv4 nameservers assigned to networks created within the network area."
}

variable "labels" {
  type        = map(string)
  nullable    = false
  description = "Labels to apply to the network area."
}
