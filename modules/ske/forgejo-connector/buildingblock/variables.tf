variable "namespace" {
  description = "Associated namespace in kubernetes cluster."
  type        = string
}

variable "repository_owner" {
  type        = string
  nullable    = false
  description = "Owner of the Forgejo repository."
}

variable "repository_name" {
  type        = string
  nullable    = false
  description = "Name of the Forgejo repository."
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
  type        = map(string)
  nullable    = false
  description = "Opaque Kubernetes secrets to create in the tenant namespace, by name, each from the Vault KV v2 secret at the given path. Every key of that secret becomes a key of the Kubernetes secret."
}

variable "harbor_host" {
  type        = string
  description = "The URL of the Harbor registry."
}

variable "vault_reader" {
  type = object({
    address  = string
    mount    = string
    username = string
    password = string
  })
  nullable    = false
  sensitive   = true
  description = "Vault KV v2 login this building block reads its secrets with: the server `address`, the engine `mount` and a userpass `username` and `password`."
}

variable "forgejo_api_token_path" {
  type        = string
  nullable    = false
  description = "Vault KV v2 secret holding the Forgejo API token under the key `forgejo_api_token`."
}

variable "registry_pull_path" {
  type        = string
  nullable    = false
  description = "Vault KV v2 secret holding the registry pull robot under the keys `username` and `password`."
}

variable "secrets_revision" {
  type        = number
  nullable    = false
  default     = 1
  description = "Revision of the Kubernetes secrets filled from Vault. Increase it to write changed values to them."

  validation {
    condition     = var.secrets_revision >= 1
    error_message = "secrets_revision must be at least 1, or the kubernetes provider writes the secrets empty."
  }
}

variable "hub_git_ref" {
  type        = string
  description = "Hub git ref this building block runs from. Pins the shared modules it sources so they stay in lockstep with this module's own checkout."
  const       = true
  default     = "main"
}
