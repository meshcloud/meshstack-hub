variable "repository_id" {
  type = number
}

variable "action_variables" {
  type        = map(string)
  description = "Map of Forgejo Actions variables to create in the repository."
  default     = {}
}

variable "action_secrets" {
  type        = map(string)
  description = "Map of Forgejo Actions secrets to create in the repository."
  sensitive   = false # the whole map is not sensitive, but map values are!
  default     = {}

  validation {
    condition     = alltrue([for key in keys(var.action_secrets) : (length(key) <= 30)])
    error_message = "Forgejo Actions secret names must be 30 characters or less."
  }
}
