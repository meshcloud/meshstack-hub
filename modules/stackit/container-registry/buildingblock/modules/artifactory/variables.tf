variable "release_on_destroy" {
  type        = bool
  nullable    = false
  description = "Leave the artifactory in place on destroy."
}

variable "path" {
  type     = string
  nullable = false
}

variable "name" {
  type     = string
  nullable = false
}
