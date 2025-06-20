variable "backplane_user_name" {
  type     = string
  nullable = false
  default  = "building-block-opt-in-region"
}

variable "backplane_role_name" {
  type        = string
  description = "Name of the role that the backplane user will assume in the management account to manage opt-in regions"
  default     = "building-block-opt-in-region"
}

