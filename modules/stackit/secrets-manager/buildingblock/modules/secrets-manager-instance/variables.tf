variable "release_on_destroy" {
  type        = bool
  nullable    = false
  description = "Leave the instance in place on destroy."
}

variable "project_id" {
  type     = string
  nullable = false
}

variable "name" {
  type     = string
  nullable = false
}
