variable "forgejo_base_url" {
  type        = string
  description = "STACKIT Git base URL"
  default     = "https://git-service.git.onstackit.cloud"
}

variable "forgejo_token" {
  type        = string
  description = "STACKIT Git Personal Access Token with write:repository and write:organization scopes"
  sensitive   = true
}

variable "forgejo_organization" {
  type        = string
  description = "Default STACKIT Git organization where repositories will be created"
}
