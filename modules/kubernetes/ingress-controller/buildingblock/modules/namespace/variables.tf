variable "release_on_destroy" {
  type        = bool
  nullable    = false
  description = "Leave the namespace in place on destroy."
}

variable "name" {
  type     = string
  nullable = false
}
