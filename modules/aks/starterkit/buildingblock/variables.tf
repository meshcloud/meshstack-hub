variable "workspace_identifier" {
  type = string
}

variable "name" {
  type        = string
  description = "This name will be used for the created projects, AKS namespaces and GitHub repository."
}

variable "full_platform_identifier" {
  type        = string
  description = "Full platform identifier of the AKS Namespace platform."
}

variable "landing_zone_dev_identifier" {
  type        = string
  description = "AKS Landing zone identifier for the development tenant."
}

variable "landing_zone_prod_identifier" {
  type        = string
  description = "AKS Landing zone identifier for the production tenant."
}

variable "github_repo_definition_version_uuid" {
  type        = string
  description = "UUID of the GitHub repository building block definition version."
}

variable "github_actions_connector_definition_version_uuid" {
  type        = string
  description = "UUID of the GitHub Actions connector building block definition version."
}

variable "github_repo_definition_uuid" {
  type        = string
  description = "UUID of the GitHub repository building block definition."
}

variable "github_repo_input_repo_visibility" {
  type        = string
  description = "Visibility of the GitHub repository (e.g., public, private)."
  default     = "private"
}

variable "github_org" {
  type        = string
  description = "GitHub organization name. Used only for display purposes."
}

variable "creator" {
  type = object({
    type        = string
    identifier  = string
    displayName = string
    username    = optional(string)
    email       = optional(string)
    euid        = optional(string)
  })
  description = "Information about the creator of the resources who will be assigned Project Admin role"
}

variable "repo_admin" {
  type        = string
  description = "GitHub handle of the user who will be assigned as the repository admin. Delete building block definition input if not needed."
  default     = null
}

variable "project_tags_yaml" {
  type        = string
  description = <<EOF
YAML configuration for project tags that will be applied to dev and prod projects. Expected structure:

```yaml
dev:
  key1:
    - "value1"
    - "value2"
  key2:
    - "value3"
prod:
  key1:
    - "value4"
  key2:
    - "value5"
    - "value6"
```
EOF
  default     = <<EOF
dev: {}
prod: {}
EOF

  validation {
    condition     = can(yamldecode(var.project_tags_yaml))
    error_message = "project_tags_yaml must be valid YAML"
  }

  validation {
    condition     = can(yamldecode(var.project_tags_yaml).dev) && yamldecode(var.project_tags_yaml).dev != null
    error_message = "dev section is required in project_tags_yaml"
  }

  validation {
    condition     = can(yamldecode(var.project_tags_yaml).prod) && yamldecode(var.project_tags_yaml).prod != null
    error_message = "prod section is required in project_tags_yaml"
  }
}
