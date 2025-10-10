variable "service_user_email" {
  description = "Email address for the IONOS service user"
  type        = string
}

variable "initial_password" {
  description = "Initial password for the IONOS service user"
  type        = string
  sensitive   = true
}

variable "group_name" {
  description = "Name of the IONOS group for DCD management"
  type        = string
  default     = "DCD-Managers"
}

variable "ionos_token" {
  description = "IONOS API token for authentication"
  type        = string
  sensitive   = true
}