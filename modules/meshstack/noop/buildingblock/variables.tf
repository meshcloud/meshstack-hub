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

# A TAG input resolves to the tag's values, and to null when the tag holds no value on the object it
# is read from — an absent key and an empty one both mean unset. Every TAG input is therefore a
# nullable list, whichever meshObject it reads from.

variable "project_tag" {
  type    = list(string)
  default = null
}

variable "payment_method_tag" {
  type    = list(string)
  default = null
}

variable "landing_zone_tag" {
  type    = list(string)
  default = null
}
