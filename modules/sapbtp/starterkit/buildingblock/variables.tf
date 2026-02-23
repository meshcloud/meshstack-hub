variable "workspace_identifier" {
  type        = string
  description = "The meshStack workspace identifier"
}

variable "name" {
  type        = string
  description = "Base name for projects and subaccounts (e.g., 'My App'). Will be normalized to 'my-app-dev' and 'my-app-prod'"
}

variable "platform_identifier" {
  type        = string
  description = "Full platform identifier of the SAP BTP platform"
}

variable "landing_zone_dev_identifier" {
  type        = string
  description = "SAP BTP landing zone identifier for the development subaccount"
}

variable "landing_zone_prod_identifier" {
  type        = string
  description = "SAP BTP landing zone identifier for the production subaccount"
}

variable "entitlements_definition_version_uuid" {
  type        = string
  description = "UUID of the entitlements building block definition version"
}

variable "entitlements" {
  type        = string
  description = "Comma-separated list of service entitlements (e.g., 'cloudfoundry.standard,APPLICATION_RUNTIME.MEMORY,auditlog-management.default')"
  default     = "cloudfoundry.standard,APPLICATION_RUNTIME.MEMORY,auditlog-management.default"
}

variable "enable_cloudfoundry" {
  type        = bool
  description = "Whether to enable Cloud Foundry environment"
  default     = false
}

variable "cloudfoundry_definition_version_uuid" {
  type        = string
  description = "UUID of the Cloud Foundry building block definition version"
  default     = ""
}

variable "cloudfoundry_plan" {
  type        = string
  description = "Cloud Foundry environment plan (standard, free, or trial)"
  default     = "standard"
}

variable "cf_services_dev" {
  type        = string
  description = "Comma-separated list of Cloud Foundry services for dev (e.g., 'postgresql.small,destination.lite')"
  default     = ""
}

variable "cf_services_prod" {
  type        = string
  description = "Comma-separated list of Cloud Foundry services for prod (e.g., 'postgresql.medium,destination.lite')"
  default     = ""
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
  description = "Information about the creator who will be assigned Project Admin role"
}

variable "project_tags_yaml" {
  type        = string
  description = <<EOF
YAML configuration for project tags:

```yaml
dev:
  environment:
    - "development"
  cost-center:
    - "CC-123"
prod:
  environment:
    - "production"
  cost-center:
    - "CC-456"
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
