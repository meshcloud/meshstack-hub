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
    roles          = list(string) # Now expects: Workspace Owner, Workspace Manager, Workspace Member
  }))

  validation {
    condition = alltrue([
      for user in var.users : alltrue([
        for role in user.roles : contains(["Workspace Owner", "Workspace Manager", "Workspace Member"], role)
      ])
    ])
    error_message = "User roles must be one of: Workspace Owner, Workspace Manager, Workspace Member."
  }
}