variable "service_account_email" {
  type        = string
  description = "Email of the STACKIT service account used to issue the Model Serving token."
}

variable "project_id" {
  type        = string
  description = "STACKIT project ID the Model Serving token is issued in."
}

variable "token_name" {
  type        = string
  description = "Display name of the Model Serving token."
}

variable "token_description" {
  type        = string
  default     = "Managed by meshStack."
  description = "Description shown on the Model Serving token."
}

variable "ttl_duration" {
  type        = string
  default     = "90d"
  description = "Lifetime of the Model Serving token, e.g. '90d'."
}

variable "region" {
  type        = string
  default     = null
  description = "STACKIT region for the Model Serving token. Defaults to the provider region."
}
