// Platform engineer configuration

variable "composition_config_yaml" {
  type        = string
  description = <<EOF
YAML configuration for landing zone and building blocks. Expected structure:

```yaml
landing_zone:
  landing_zone_identifier: "my-landing-zone"
  platform_identifier: "my-platform"
budget_alert_building_block:
  definition_uuid: "uuid-here"
  definition_version: 1
enable_eu_south_2_region_building_block:
  definition_uuid: "uuid-here"
  definition_version: 1
project:
  default_tags:
    environment: "sandbox"
    cost_center: "engineering"
  owner_tag_key: "project_owner"  # optional, if not set no project owner tag will be set
```
EOF

  validation {
    condition     = can(yamldecode(var.composition_config_yaml))
    error_message = "composition_config_yaml must be valid YAML"
  }

  validation {
    condition     = can(yamldecode(var.composition_config_yaml).landing_zone.landing_zone_identifier) && yamldecode(var.composition_config_yaml).landing_zone.landing_zone_identifier != null
    error_message = "landing_zone.landing_zone_identifier is required in composition_config_yaml"
  }

  validation {
    condition     = can(yamldecode(var.composition_config_yaml).landing_zone.platform_identifier) && yamldecode(var.composition_config_yaml).landing_zone.platform_identifier != null
    error_message = "landing_zone.platform_identifier is required in composition_config_yaml"
  }

  validation {
    condition     = can(yamldecode(var.composition_config_yaml).budget_alert_building_block.definition_uuid) && yamldecode(var.composition_config_yaml).budget_alert_building_block.definition_uuid != null
    error_message = "budget_alert_building_block.definition_uuid is required in composition_config_yaml"
  }

  validation {
    condition     = can(yamldecode(var.composition_config_yaml).budget_alert_building_block.definition_version) && yamldecode(var.composition_config_yaml).budget_alert_building_block.definition_version != null
    error_message = "budget_alert_building_block.definition_version is required in composition_config_yaml"
  }

  validation {
    condition     = can(yamldecode(var.composition_config_yaml).enable_eu_south_2_region_building_block.definition_uuid) && yamldecode(var.composition_config_yaml).enable_eu_south_2_region_building_block.definition_uuid != null
    error_message = "enable_eu_south_2_region_building_block.definition_uuid is required in composition_config_yaml"
  }

  validation {
    condition     = can(yamldecode(var.composition_config_yaml).enable_eu_south_2_region_building_block.definition_version) && yamldecode(var.composition_config_yaml).enable_eu_south_2_region_building_block.definition_version != null
    error_message = "enable_eu_south_2_region_building_block.definition_version is required in composition_config_yaml"
  }
}

// meshStack auto-configuration

variable "workspace_identifier" {
  description = "Identifier for the owning workspace"
  type        = string
}


// End-user configuration

variable "username" {
  description = "meshStack username of the project contact. This should be an email."
  type        = string
}

variable "budget_amount" {
  description = "Monthly budget amount. You will receive an alert when the budget is exceeded."
  type        = number
}