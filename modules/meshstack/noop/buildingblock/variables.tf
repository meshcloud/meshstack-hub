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
