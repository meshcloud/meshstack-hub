
variable "backplane_project_id" {
  type        = string
  description = "The project hosting the building block backplane resources"
}

variable "billing_account_id" {
  type        = string
  description = "The billing account ID where budget permissions will be granted"
}

variable "backplane_service_account_name" {
  type        = string
  description = "The name of the service account to be created for the backplane"
  default     = "building-block-budget-alert"
}