provider "meshstack" {
  # configured via env vars
}

## Note: this composition is configured through a single flat YAML input so that a platform operator can
## configure it in one place right after importing it from meshStack Hub. It is written in the most
## human-readable form the provider can actually resolve: the platform and the landing zone are named by
## their identifiers, while the building block definition versions have to be uuids because the provider
## has no data source that resolves a definition (or one of its versions) by uuid or by name.

locals {
  # Parse YAML configuration - validation is now handled at the variable level
  config = yamldecode(var.composition_config_yaml)

  # Direct access to configuration values (no need for null checks since validation ensures they exist)
  landing_zone_identifier = local.config.landing_zone.landing_zone_identifier
  platform_identifier     = local.config.landing_zone.platform_identifier

  budget_alert_definition_version_uuid             = local.config.budget_alert_building_block.definition_version_uuid
  enable_eu_south_2_region_definition_version_uuid = local.config.enable_eu_south_2_region_building_block.definition_version_uuid

  # Project configuration with safe defaults
  project_config        = try(local.config.project, {})
  project_default_tags  = try(local.project_config.default_tags, {})
  project_owner_tag_key = try(local.project_config.owner_tag_key, null)
}

resource "random_string" "suffix" {
  length  = 3
  special = false
  upper   = false
}

locals {
  # Extract username from email address (everything before @)
  username_prefix    = substr(regex("^([^@]+)", var.username)[0], 0, 12)
  project_identifier = "acs-${local.username_prefix}-${random_string.suffix.result}"

  # Project owner tag logic
  project_owner_tag = local.project_owner_tag_key != null ? { (local.project_owner_tag_key) = [var.username] } : {}
}

resource "meshstack_project" "sandbox" {
  # We had a v1 of this building block that asked the user to provide a project name. This lead to naming conflicts
  # that end-users could not resolve themselves, so we now generate a project name automatically to avoid that.
  # However, the project.metadata.name is an immutable identifier so we must be careful to not change it for
  # building blocks that did succeessfully provision a project before.
  lifecycle {
    ignore_changes = [
      metadata.name, # ignore changes to the project name, we set it via the local variable
    ]
  }

  metadata = {
    name               = local.project_identifier
    owned_by_workspace = var.workspace_identifier
  }
  spec = {
    display_name = "Agentic Coding Sandbox ${var.username}"
    tags         = merge(local.project_default_tags, local.project_owner_tag)
  }
}


# meshstack_tenant runs on the meshTenant v4 API, which references its platform by uuid. Platform
# operators configure this composition with a platform identifier, so look the platform up by its
# full identifier (`<platform-name>.<location-name>`) and reuse the ref the data source computes.
data "meshstack_platforms" "available" {}

locals {
  platform_ref = one([
    for platform in data.meshstack_platforms.available.platforms : platform.ref
    if platform.identifier == local.platform_identifier
  ])
}

resource "meshstack_tenant" "sandbox" {
  metadata = {
    owned_by_workspace = meshstack_project.sandbox.metadata.owned_by_workspace
    owned_by_project   = meshstack_project.sandbox.metadata.name
  }

  spec = {
    platform_ref = local.platform_ref
    landing_zone_ref = {
      name = local.landing_zone_identifier
    }
  }

  lifecycle {
    precondition {
      condition     = local.platform_ref != null
      error_message = "No platform with identifier '${local.platform_identifier}' is visible to this composition's meshStack API key. Check landing_zone.platform_identifier in composition_config_yaml and that the API key is allowed to list platforms."
    }
  }
}


resource "meshstack_building_block" "budget_alert" {
  spec = {
    building_block_definition_version_ref = {
      uuid = local.budget_alert_definition_version_uuid
    }

    display_name = "Budget Alert"
    target_ref   = meshstack_tenant.sandbox.ref

    inputs = {
      budget_name           = { value = jsonencode("Agentic Coding Budget Alert") }
      monthly_budget_amount = { value = jsonencode(var.budget_amount) }
      # just a single email for now, not a comma-separated list
      contact_emails = { value = jsonencode(var.username) }
    }
  }
}


# enable spain region for the sandbox tenant because that's the only region where Anthropic's Sonnet 4 is available
resource "meshstack_building_block" "enable_eu_south_2_region" {
  spec = {
    building_block_definition_version_ref = {
      uuid = local.enable_eu_south_2_region_definition_version_uuid
    }

    display_name = "Enable eu-south-2 region"
    target_ref   = meshstack_tenant.sandbox.ref

    inputs = {
      region = { value = jsonencode("eu-south-2") }
    }
  }
}

# note: this does not work until API keys get support for an ADM level permission on project role bidnings
# resource "meshstack_project_user_binding" "sandbox_owner" {
#   metadata = {
#     name = "sandbox-owner" # assuming the binding name only needs to be unique within the project
#   }

#   role_ref = {
#     name = "Project Admin"
#   }

#   target_ref = {
#     owned_by_workspace = meshstack_project.sandbox.metadata.owned_by_workspace
#     name               = meshstack_project.sandbox.metadata.name
#   }

#   subject = {
#     name = var.username
#   }
# }