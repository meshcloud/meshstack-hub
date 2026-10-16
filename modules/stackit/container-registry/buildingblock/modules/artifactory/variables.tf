variable "release_on_destroy" {
  type        = bool
  nullable    = false
  description = "Leave the artifactory in place when it is destroyed, and only drop it from the state."
}

variable "path" {
  type     = string
  nullable = false
}

variable "name" {
  type     = string
  nullable = false
}
