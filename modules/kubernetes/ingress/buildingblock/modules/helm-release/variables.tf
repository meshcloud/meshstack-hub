variable "release_on_destroy" {
  type        = bool
  nullable    = false
  description = "Leave the release in place when it is destroyed, and only drop it from the state."
}

variable "name" {
  type     = string
  nullable = false
}

variable "namespace" {
  type     = string
  nullable = false
}

variable "repository" {
  type     = string
  nullable = true
  default  = null
}

variable "chart" {
  type     = string
  nullable = false
}

variable "chart_version" {
  type     = string
  nullable = true
  default  = null
}

variable "values" {
  type     = list(string)
  nullable = false
}

variable "take_ownership" {
  type     = bool
  nullable = false
  default  = false
}

variable "atomic" {
  type     = bool
  nullable = false
  default  = false
}

variable "timeout" {
  type     = number
  nullable = false
}
