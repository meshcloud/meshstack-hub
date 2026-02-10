locals {
  # Create a purely alphanumeric identifier from the display name
  # Remove special characters, convert to lowercase, and replace spaces/hyphens with nothing
  identifier = lower(replace(replace(var.name, "/[^a-zA-Z0-9\\s\\-\\_]/", ""), "/[\\s\\-\\_]+/", "-"))

  # Decode project tags YAML configuration
  project_tags_config = yamldecode(var.project_tags_yaml)

  repo_name = "${local.identifier}-${random_id.repo_suffix.hex}"
}

# Generate a random suffix for the repository name to ensure uniqueness
resource "random_id" "repo_suffix" {
  byte_length = 4 // 8 hex characters
}

resource "meshstack_project" "dev" {
  metadata = {
    name               = "${local.identifier}-dev"
    owned_by_workspace = var.workspace_identifier
  }
  spec = {
    display_name = "${var.name} Dev"
    tags         = try(local.project_tags_config.dev, {})
  }
}

resource "meshstack_project" "prod" {
  metadata = {
    name               = "${local.identifier}-prod"
    owned_by_workspace = var.workspace_identifier
  }
  spec = {
    display_name = "${var.name} Prod"
    tags         = try(local.project_tags_config.prod, {})
  }
}

resource "meshstack_project_user_binding" "creator_dev_admin" {
  count = var.creator.type == "User" && var.creator.username != null ? 1 : 0

  metadata = {
    name = uuid()
  }

  role_ref = {
    name = "Project Admin"
  }

  target_ref = {
    owned_by_workspace = var.workspace_identifier
    name               = meshstack_project.dev.metadata.name
  }

  subject = {
    name = var.creator.username
  }
}

resource "meshstack_project_user_binding" "creator_prod_admin" {
  count = var.creator.type == "User" && var.creator.username != null ? 1 : 0

  metadata = {
    name = uuid()
  }

  role_ref = {
    name = "Project Admin"
  }

  target_ref = {
    owned_by_workspace = var.workspace_identifier
    name               = meshstack_project.prod.metadata.name
  }

  subject = {
    name = var.creator.username
  }
}

resource "meshstack_tenant_v4" "dev" {
  metadata = {
    owned_by_workspace = var.workspace_identifier
    owned_by_project   = meshstack_project.dev.metadata.name
  }

  spec = {
    platform_identifier     = var.full_platform_identifier
    landing_zone_identifier = var.landing_zone_dev_identifier
  }
}

resource "meshstack_tenant_v4" "prod" {
  metadata = {
    owned_by_workspace = var.workspace_identifier
    owned_by_project   = meshstack_project.prod.metadata.name
  }

  spec = {
    platform_identifier     = var.full_platform_identifier
    landing_zone_identifier = var.landing_zone_prod_identifier
  }
}

resource "meshstack_building_block_v2" "repo" {
  spec = {
    building_block_definition_version_ref = {
      uuid = var.github_repo_definition_version_uuid
    }

    display_name = "${var.github_org}/${local.identifier}"
    target_ref = {
      kind       = "meshWorkspace"
      identifier = var.workspace_identifier
    }

    inputs = {
      repo_name = {
        value_string = local.repo_name
      }
      archive_repo_on_destroy = {
        value_bool = var.archive_repo_on_destroy
      }
      repo_owner = {
        value_string = var.repo_admin != null ? var.repo_admin : "null"
      }
      repo_visibility = {
        value_string = var.github_repo_input_repo_visibility != null ? var.github_repo_input_repo_visibility : "private"
      }
      use_template = {
        value_bool = true
      }
      template_owner = {
        value_string = "likvid-bank"
      }
      template_repo = {
        value_string = "aks-starterkit-template"
      }
    }
  }
}

resource "meshstack_building_block_v2" "github_actions_dev" {
  spec = {
    building_block_definition_version_ref = {
      uuid = var.github_actions_connector_definition_version_uuid
    }
    target_ref = {
      kind = "meshTenant"
      uuid = meshstack_tenant_v4.dev.metadata.uuid
    }
    display_name = "GHA Connector Dev"
    parent_building_blocks = [{
      buildingblock_uuid = meshstack_building_block_v2.repo.metadata.uuid
      definition_uuid    = var.github_repo_definition_uuid
    }]
    inputs = {
      github_environment_name = {
        value_string = "development"
      }
      additional_environment_variables = {
        value_code = jsonencode({
          "DOMAIN_NAME"        = "${local.identifier}-dev"
          "AKS_NAMESPACE_NAME" = meshstack_tenant_v4.dev.spec.platform_tenant_id
        })
      }
    }
  }
}

resource "meshstack_building_block_v2" "github_actions_prod" {
  depends_on = [meshstack_building_block_v2.github_actions_dev]

  spec = {
    display_name = "GHA Connector Prod"
    building_block_definition_version_ref = {
      uuid = var.github_actions_connector_definition_version_uuid
    }
    target_ref = {
      kind = "meshTenant"
      uuid = meshstack_tenant_v4.prod.metadata.uuid
    }
    parent_building_blocks = [{
      buildingblock_uuid = meshstack_building_block_v2.repo.metadata.uuid
      definition_uuid    = var.github_repo_definition_uuid
    }]
    inputs = {
      github_environment_name = {
        value_string = "production"
      }
      additional_environment_variables = {
        value_code = jsonencode({
          "DOMAIN_NAME"        = local.identifier
          "AKS_NAMESPACE_NAME" = meshstack_tenant_v4.prod.spec.platform_tenant_id
        })
      }
    }
  }
}
