variable "project_id" {
  description = "The GCP project ID"
  type        = string
}

variable "service_account_id" {
  description = "The ID of the service account to create"
  type        = string
  default     = "buildingblock-storage-sa"
}