variable "namespace" {
  description = "Associated namespace in kubernetes cluster."
  type        = string
}

variable "repository_id" {
  type        = number
  description = "The ID of the Forgejo repository."
}

variable "stage" {
  type        = string
  description = "Deployment stage used for Forgejo workflow dispatch and action secret naming. Allowed values: dev, prod."

  validation {
    condition     = contains(["dev", "prod"], lower(var.stage))
    error_message = "stage must be one of: dev, prod."
  }
}

variable "additional_kubernetes_secrets" {
  type        = map(map(string))
  description = "Additional Kubernetes secrets to create in the tenant namespace. Map keys are secret names, values are secret data maps."
  default     = {}
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
