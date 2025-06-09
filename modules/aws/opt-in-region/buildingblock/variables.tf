variable "assume_role_arn" {
  type        = string
  description = "The ARN of the role in the organization management account that the building block will assume to manage opt-in regions"
}

variable "account_id" {
  type        = string
  description = "The ID of the target account where the opt-in region will be managed"
}

variable "enabled" {
  type        = bool
  description = "Whether the region is enabled"
  default     = true
}

variable "region_name" {
  type        = string
  description = "The region name to manage (e.g., ap-southeast-3, me-central-1, af-south-1)"
}
