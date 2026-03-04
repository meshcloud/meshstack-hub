variable "workspace_identifier" {
  type = string
}

variable "name" {
  type        = string
  description = "This name will be used for the created projects."
}

variable "full_platform_identifier" {
  type        = string
  description = "Full platform identifier of the SKE platform."
}

variable "landing_zone_dev_identifier" {
  type        = string
  description = "SKE Landing zone identifier for the development tenant."
}

variable "landing_zone_prod_identifier" {
  type        = string
  description = "SKE Landing zone identifier for the production tenant."
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
  default     = "{\"dev\": {}, \"prod\": {}}"

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
