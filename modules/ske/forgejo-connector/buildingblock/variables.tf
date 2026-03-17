variable "namespace" {
  description = "Associated namespace in kubernetes cluster."
  type        = string
}

variable "repository_id" {
  type        = number
  description = "The ID of the Forgejo repository."
}

variable "repository_secret_name_suffix" {
  type        = string
  description = "Optional suffix appended to created repository secret names."
  default     = ""
}

variable "harbor_host" {
  type        = string
  description = "The URL of the Harbor registry."
  default     = "https://registry.onstackit.cloud"
}

variable "harbor_username" {
  type        = string
  description = "The username for the Harbor registry."
  sensitive   = true
}

variable "harbor_password" {
  type        = string
  description = "The password for the Harbor registry."
  sensitive   = true
}