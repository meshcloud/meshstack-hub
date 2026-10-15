variable "project_name" {
  type        = string
  nullable    = false
  description = "The name of the Tencent Cloud project to create."
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
  default = []
}
