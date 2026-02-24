variable "gitea_base_url" {
  type        = string
  description = "STACKIT Git base URL"
  default     = "https://git-service.git.onstackit.cloud"
}

variable "gitea_token" {
  type        = string
  description = "STACKIT Git Personal Access Token with write:repository, write:organization, and read:user scopes"
  sensitive   = true
}

variable "gitea_organization" {
  type        = string
  description = "Default STACKIT Git organization where repositories will be created"
}
