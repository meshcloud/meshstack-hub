variable "region" {
  type        = string
  default     = "eu-de"
  nullable    = false
  description = "T Cloud Public region of the project."
}

variable "project_id" {
  type        = string
  nullable    = false
  description = "ID of the project the network is created in."
}

variable "name" {
  type        = string
  default     = "app"
  nullable    = false
  description = "Name of the VPC and of its subnet. The RDS and CCE building blocks find the network by this name."

  validation {
    condition     = can(regex("^[a-zA-Z0-9_-]{1,56}$", var.name))
    error_message = "name must be 1-56 letters, digits, dashes or underscores."
  }
}

variable "cidr_block" {
  type        = string
  default     = "10.0.0.0/16"
  nullable    = false
  description = "IP range of the VPC."

  validation {
    condition     = can(cidrnetmask(var.cidr_block))
    error_message = "cidr_block must be an IPv4 CIDR range, such as 10.0.0.0/16."
  }
}

variable "subnet_cidr" {
  type        = string
  default     = "10.0.0.0/24"
  nullable    = false
  description = "IP range of the subnet, inside `cidr_block`."

  validation {
    condition     = can(cidrnetmask(var.subnet_cidr))
    error_message = "subnet_cidr must be an IPv4 CIDR range, such as 10.0.0.0/24."
  }
}

variable "snat_enabled" {
  type        = bool
  default     = true
  nullable    = false
  description = "Creates a NAT gateway with an elastic IP, so that servers in the subnet reach the internet without public IPs of their own."
}
