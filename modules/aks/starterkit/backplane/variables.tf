variable "hub" {
  type = object({
    git_ref = string
  })
  description = "Hub release reference. Set git_ref to a tag (e.g. 'v1.2.3') or branch for the meshstack-hub repo."
}

variable "meshstack" {
  type = object({
    owning_workspace_identifier = string
  })
  description = "Shared meshStack context passed down from the IaC runtime."
}

variable "github" {
  type = object({
    org                        = string
    app_id                     = string
    app_installation_id        = string
    app_pem_file               = string
    connector_config_tf_base64 = string
  })
  sensitive   = true
  description = "GitHub App credentials and connector configuration."
}

variable "postgresql" {
  description = "When non-null, registers the azure/postgresql BBD as part of the starterkit composition. Omit/null for deployments that don't need PostgreSQL."
  type        = object({})
  default     = null
}
