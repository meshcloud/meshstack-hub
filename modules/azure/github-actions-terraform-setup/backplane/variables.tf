variable "application_name" {
  type     = string
  nullable = false
}

# tflint-ignore: terraform_unused_declarations
variable "location" {
  type        = string
  nullable    = false
  description = "Azure location for deploying the building block terraform state storage account"
}

variable "scope" {
  type        = string
  nullable    = false
  description = "Scope where the building block should be deployable, typically a Sandbox Landing Zone Management Group"
}
