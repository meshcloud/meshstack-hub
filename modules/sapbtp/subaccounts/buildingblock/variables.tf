variable "globalaccount" {
  type        = string
  description = "The subdomain of the global account in which you want to manage resources."
}

variable "region" {
  type        = string
  default     = "eu30"
  description = "The region of the subaccount."
}

variable "workspace_identifier" {
  type        = string
  description = "The meshStack workspace identifier."
}

variable "project_identifier" {
  type        = string
  description = "The meshStack project identifier."
}

variable "parent_id" {
  description = "The ID of the parent resource."
  type        = string
}

# note: these permissions are passed in from meshStack and automatically updated whenever something changes
# atm. we are not using them inside this building block implementation, but they give us a trigger to often reconcile
# the permissions
variable "users" {
  type = list(object(
    {
      meshIdentifier = string
      username       = string
      firstName      = string
      lastName       = string
      email          = string
      euid           = string
      roles          = list(string)
    }
  ))
  description = "Users and their roles provided by meshStack"
  default     = []
}
