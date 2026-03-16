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

variable "repository_id" {
  type        = string
  description = "The ID of the Forgejo repository."
}

variable "stage" {
  type        = string
  description = "Deployment stage used for secret suffixing (`dev` or `prod`)."

  validation {
    condition     = can(regex("^(dev|prod)$", var.stage))
    error_message = "stage must be either 'dev' or 'prod'."
  }
}

variable "namespace" {
  description = "Associated namespace in kubernetes cluster."
  type        = string
}
