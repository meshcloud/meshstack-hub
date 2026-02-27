# ── Backplane inputs (static, set once per building block definition) ──────────

variable "gitea_base_url" {
  type        = string
  description = "STACKIT Git (Forgejo) base URL."
  default     = "https://git-service.git.onstackit.cloud"
}

variable "gitea_token" {
  type        = string
  description = "STACKIT Git API token with permissions to manage repository secrets."
  sensitive   = true
}

variable "gitea_organization" {
  type        = string
  description = "STACKIT Git organization that owns the repository."
}

# ── Inputs wired from parent building block / platform ────────────────────────

variable "namespace" {
  type        = string
  description = "SKE namespace to connect the Forgejo Actions pipeline to."
}

variable "repository_name" {
  type        = string
  description = "Name of the Forgejo repository to store deployment secrets in."
}

variable "cluster_server" {
  type        = string
  description = "SKE cluster API server URL for kubeconfig generation."
}

variable "cluster_ca_certificate" {
  type        = string
  description = "Base64-encoded CA certificate of the SKE cluster."
}

# ── Optional container registry credentials ──────────────────────────────────

variable "harbor" {
  type = object({
    url            = string
    robot_username = string
    robot_token    = string
  })
  sensitive   = true
  default     = null
  description = "Harbor registry credentials. When provided, stores push credentials as Forgejo Actions secrets and creates an image pull secret in the namespace."
}
