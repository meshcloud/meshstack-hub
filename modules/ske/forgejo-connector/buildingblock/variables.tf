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
  description = "Deployment stage used for Forgejo workflow dispatch and action secret naming."

  validation {
    condition     = can(regex("^[a-z]+$", var.stage))
    error_message = "stage must match ^[a-z]+$."
  }
}

variable "app_hostname" {
  type        = string
  description = "Public application hostname for this stage (used by deploy workflow and ingress)."
}

variable "additional_kubernetes_secrets" {
  type        = map(map(string))
  description = "Additional Kubernetes secrets to create in the tenant namespace. Map keys are secret names, values are secret data maps."
}

variable "harbor_host" {
  type        = string
  description = "The URL of the Harbor registry."
}

variable "container_registry_access_credentials" {
  type = object({
    push = object({ user = string, password = string })
    pull = object({ user = string, password = string })
  })
  description = "Registry robot credentials. Null wires no registry, so pods pull public images only."
  sensitive   = true
  default     = null
}

variable "hub_git_ref" {
  type        = string
  description = "Hub git ref this building block runs from. Pins the shared modules it sources so they stay in lockstep with this module's own checkout."
  const       = true
  default     = "main"
}
