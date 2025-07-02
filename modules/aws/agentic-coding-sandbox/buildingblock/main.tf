provider "meshstack" {
  # configured via env vars
}

## Note: all of this is arguably a not so pretty workaround for missing data objects in meshStack's terraform provider
## to locate the right BBDs and LZs.
## But for now this provides a suitable way to have a single platform operator input for configuring the BBD after
## importing it from meshStack Hub, so we'll run with this approach for now until we discover something better.

locals {
  # Parse YAML configuration - validation is now handled at the variable level
  config = yamldecode(var.composition_config_yaml)

  # Direct access to configuration values (no need for null checks since validation ensures they exist)
  landing_zone_identifier = local.config.landing_zone.landing_zone_identifier
  platform_identifier     = local.config.landing_zone.platform_identifier

  budget_alert_definition_uuid    = local.config.budget_alert_building_block.definition_uuid
  budget_alert_definition_version = local.config.budget_alert_building_block.definition_version

  enable_eu_south_2_region_definition_uuid    = local.config.enable_eu_south_2_region_building_block.definition_uuid
  enable_eu_south_2_region_definition_version = local.config.enable_eu_south_2_region_building_block.definition_version

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


resource "meshstack_tenant" "sandbox" {
  metadata = {
    owned_by_workspace  = meshstack_project.sandbox.metadata.owned_by_workspace
    owned_by_project    = meshstack_project.sandbox.metadata.name
    platform_identifier = local.platform_identifier
  }

  spec = {
    landing_zone_identifier = local.landing_zone_identifier
  }
}


# NOTE: must use bb v1 resource because v2 requires a tenant uuid
# but the tenant v4 api that delivers the uuid is not supported by  our terraform provider yet
resource "meshstack_buildingblock" "budget_alert" {
  metadata = {
    definition_uuid    = local.budget_alert_definition_uuid
    definition_version = local.budget_alert_definition_version
    tenant_identifier  = "${meshstack_tenant.sandbox.metadata.owned_by_workspace}.${meshstack_tenant.sandbox.metadata.owned_by_project}.${meshstack_tenant.sandbox.metadata.platform_identifier}"
  }

  spec = {
    display_name = "Budget Alert"

    inputs = {
      budget_name = {
        value_string = "Agentic Coding Budget Alert"
      }
      monthly_budget_amount = {
        value_int = var.budget_amount
      }
      contact_emails = {
        # just a single email for now, not a comma-separated list
        value_string = var.username
      }
    }
  }
}


# enable spain region for the sandbox tenant because that's the only region where Anthropic's Sonnet 4 is available
resource "meshstack_buildingblock" "enable_eu_south_2_region" {
  metadata = {
    definition_uuid    = local.enable_eu_south_2_region_definition_uuid
    definition_version = local.enable_eu_south_2_region_definition_version
    tenant_identifier  = "${meshstack_tenant.sandbox.metadata.owned_by_workspace}.${meshstack_tenant.sandbox.metadata.owned_by_project}.${meshstack_tenant.sandbox.metadata.platform_identifier}"
  }

  spec = {
    display_name = "Enable eu-south-2 region"

    inputs = {
      region = {
        value_single_select = "eu-south-2"
      }
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