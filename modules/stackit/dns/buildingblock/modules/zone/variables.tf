variable "release_on_destroy" {
  type        = bool
  nullable    = false
  description = "Leave the zone in place on destroy."
}

variable "project_id" {
  type     = string
  nullable = false
}

variable "name" {
  type     = string
  nullable = false
}

variable "dns_name" {
  type     = string
  nullable = false
}

variable "contact_email" {
  type     = string
  nullable = false
}

variable "default_ttl" {
  type     = number
  nullable = false
}
