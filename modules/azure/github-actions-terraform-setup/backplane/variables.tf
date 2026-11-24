variable "application_name" {
  type     = string
  nullable = false
}

variable "scope" {
  type        = string
  nullable    = false
  description = "Scope where the building block should be deployable, typically a Sandbox Landing Zone Management Group"
}
