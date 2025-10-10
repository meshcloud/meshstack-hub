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

variable "ionos_token" {
  description = "IONOS API token for authentication"
  type        = string
  sensitive   = true
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