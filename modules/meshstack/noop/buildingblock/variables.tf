variable "user_permissions" {
  type = list(object({
    meshIdentifier = string
    username       = string
    firstName      = string
    lastName       = string
    email          = string
    euid           = string
    roles          = list(string)
  }))
}

variable "user_permissions_json" {
  type = string
}

variable "sensitive_yaml" {
  type      = any
  sensitive = true
}

variable "static" {
  type = string
}

variable "static_code" {
  type = map(string)
}

variable "tag_value" {
  # meshStack sends a TAG input as a JSON array of strings; a tag with no value resolves to null.
  type     = list(string)
  nullable = true
}

variable "flag" {
  type = bool
}

variable "num" {
  type = number
}

variable "text" {
  type = string
}

variable "optional_text" {
  type    = string
  default = "tf-default-value"
}

variable "conditional_text" {
  # Sent only while its BBD `condition` holds; falls back to this default otherwise, exactly like optional_text.
  type    = string
  default = "tf-default-value"
}

variable "hidden_conditional_text" {
  # Its BBD `condition` (`input.flag == false`) never holds in this module's e2e tests, since flag
  # is always true there, so this default is what every run actually uses.
  type    = string
  default = "tf-default-value"
}

variable "deploy_settings" {
  # meshStack decodes a JSON-type input into the Terraform variable's declared type, matching the
  # shape of the json_schema below — same as a CODE input decodes into whatever type its variable
  # declares (see tag_value, static_code).
  type = object({
    greeting = string
    shout    = optional(bool)
  })
}

variable "sensitive_text" {
  type      = string
  sensitive = true
}

variable "single_select" {
  type = string
}

variable "multi_select" {
  type = list(string)
}

variable "multi_select_json" {
  type = string
}

variable "author" {
  type = object({
    type        = string
    identifier  = string
    displayName = string
    username    = optional(string)
    email       = optional(string)
    euid        = optional(string)
  })
  description = "Principal that ordered this building block, injected by the AUTHOR assignment type."
}

variable "operator_text" {
  type        = string
  description = "Value a platform operator filled in for this block."
}

variable "workspace_identifier" {
  type        = string
  description = "Identifier of the workspace this block belongs to, injected by meshStack."
}
