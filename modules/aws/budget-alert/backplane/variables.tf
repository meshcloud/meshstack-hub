variable "backplane_user_name" {
  type     = string
  nullable = false
  default  = "building-block-budget-alert"
}

variable "building_block_target_account_access_role_name" {
  type        = string
  description = "Name of the role that the backplane user will assume in the target account"
  default     = "building-block-budget-alert"
}

variable "building_block_target_ou_ids" {
  type        = set(string)
  description = "List of OUs that the building block can be deployed to. Accounts in these OUs will receive the building_block_backplane_account_access_role"
}