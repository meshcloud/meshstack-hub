variable "release_on_destroy" {
  type        = bool
  nullable    = false
  description = "Leave the record set in place on destroy."
}

variable "project_id" {
  type     = string
  nullable = false
}

variable "zone_id" {
  type     = string
  nullable = false
}

variable "name" {
  type     = string
  nullable = false
}

variable "records" {
  type     = list(string)
  nullable = false
}

variable "comment" {
  type     = string
  nullable = false
}
