variable "release_on_destroy" {
  type        = bool
  nullable    = false
  description = "Leave the project in place when it is destroyed, and only drop it from the state."
}

variable "metadata" {
  type = object({
    name               = string
    owned_by_workspace = string
  })
  nullable = false
}

variable "spec" {
  type = object({
    display_name              = string
    payment_method_identifier = string
    tags                      = map(list(string))
  })
  nullable = false
}
