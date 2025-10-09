variable "datacenter_name" {
  description = "Name of the IONOS DCD datacenter"
  type        = string
}

variable "datacenter_location" {
  description = "Location for the IONOS datacenter"
  type        = string
  default     = "de/fra"

  validation {
    condition = contains([
      "us/las", "us/ewr", "de/fra", "de/fkb", "de/txl",
      "gb/lhr", "es/vit", "fr/par"
    ], var.datacenter_location)
    error_message = "Datacenter location must be one of the supported IONOS locations."
  }
}

variable "datacenter_description" {
  description = "Description of the datacenter"
  type        = string
  default     = "Managed by Terraform"
}

variable "default_user_password" {
  description = "Default password for created users"
  type        = string
  sensitive   = true
}

variable "force_sec_auth" {
  description = "Force two-factor authentication for users"
  type        = bool
  default     = true
}

variable "users" {
  description = "List of users from authoritative system"
  type = list(object({
    meshIdentifier = string
    username       = string
    firstName      = string
    lastName       = string
    email          = string
    euid           = string
    roles          = list(string)
  }))
}