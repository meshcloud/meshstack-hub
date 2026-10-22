variable "release_on_destroy" {
  type        = bool
  nullable    = false
  description = "Leave the namespace in place when it is destroyed, and only drop it from the state."
}

variable "name" {
  type     = string
  nullable = false
}
