locals {
  # Create a purely alphanumeric identifier from the display name
  # Remove special characters, convert to lowercase, and replace spaces/hyphens with nothing
  identifier = lower(replace(replace(var.name, "/[^a-zA-Z0-9\\s\\-\\_]/", ""), "/[\\s\\-\\_]+/", "-"))

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
    tags         = var.project_tags.dev
  }
}

resource "meshstack_project" "prod" {
  metadata = {
    name               = "${local.identifier}-prod"
    owned_by_workspace = var.workspace_identifier
  }
  spec = {
    display_name = "${var.name} Prod"
    tags         = var.project_tags.prod
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

# Resolves the platform's full identifier (`<platform>.<location>`) from its ref, for meshPanel deep-links.
data "meshstack_platform" "this" {
  metadata = {
    uuid = var.platform_ref.uuid
  }
}

resource "meshstack_tenant" "dev" {
  metadata = {
    owned_by_workspace = var.workspace_identifier
    owned_by_project   = meshstack_project.dev.metadata.name
  }

  spec = {
    platform_ref     = var.platform_ref
    landing_zone_ref = var.landing_zone_refs["dev"]
  }

  depends_on = [meshstack_project_user_binding.creator_dev_admin]
}

resource "meshstack_tenant" "prod" {
  metadata = {
    owned_by_workspace = var.workspace_identifier
    owned_by_project   = meshstack_project.prod.metadata.name
  }

  spec = {
    platform_ref     = var.platform_ref
    landing_zone_ref = var.landing_zone_refs["prod"]
  }

  depends_on = [meshstack_project_user_binding.creator_prod_admin]
}

# Anticipates terraform-provider-meshstack v0.24.0 (#226): meshstack_tenant now runs on the
# meshTenant v4 API, so meshstack_tenant_v4 usages migrate here in place (both share the v4 body).
moved {
  from = meshstack_tenant_v4.dev
  to   = meshstack_tenant.dev
}

moved {
  from = meshstack_tenant_v4.prod
  to   = meshstack_tenant.prod
}

resource "meshstack_building_block" "repo" {
  spec = {
    building_block_definition_version_ref = {
      uuid = var.github_repo_definition_version_uuid
    }

    display_name = "${var.github_org}/${local.identifier}"
    target_ref = {
      kind = "meshWorkspace"
      name = var.workspace_identifier
    }

    inputs = {
      repo_name = {
        value = jsonencode(local.repo_name)
      }
      archive_repo_on_destroy = {
        value = jsonencode(var.archive_repo_on_destroy)
      }
      repo_owner = {
        value = jsonencode(var.repo_admin != null ? var.repo_admin : "null")
      }
      repo_visibility = {
        value = jsonencode(var.github_repo_input_repo_visibility != null ? var.github_repo_input_repo_visibility : "private")
      }
      use_template = {
        value = jsonencode(true)
      }
      template_owner = {
        value = jsonencode(split("/", var.github_template_repo_path)[0])
      }
      template_repo = {
        value = jsonencode(split("/", var.github_template_repo_path)[1])
      }
    }
  }
}

resource "meshstack_building_block" "github_actions_dev" {
  spec = {
    building_block_definition_version_ref = {
      uuid = var.github_actions_connector_definition_version_uuid
    }
    target_ref = {
      kind = "meshTenant"
      uuid = meshstack_tenant.dev.metadata.uuid
    }
    display_name = "GHA Connector Dev"
    parent_building_blocks = [{
      buildingblock_uuid = meshstack_building_block.repo.metadata.uuid
      definition_uuid    = var.github_repo_definition_uuid
    }]
    inputs = {
      github_environment_name = {
        value = jsonencode("development")
      }
      additional_environment_variables = {
        value = jsonencode(jsonencode({
          "DOMAIN_NAME"        = "${local.identifier}-dev"
          "AKS_NAMESPACE_NAME" = meshstack_tenant.dev.spec.platform_tenant_id
        }))
      }
    }
  }
}

resource "meshstack_building_block" "github_actions_prod" {
  spec = {
    display_name = "GHA Connector Prod"
    building_block_definition_version_ref = {
      uuid = var.github_actions_connector_definition_version_uuid
    }
    target_ref = {
      kind = "meshTenant"
      uuid = meshstack_tenant.prod.metadata.uuid
    }
    parent_building_blocks = [{
      buildingblock_uuid = meshstack_building_block.repo.metadata.uuid
      definition_uuid    = var.github_repo_definition_uuid
    }]
    inputs = {
      github_environment_name = {
        value = jsonencode("production")
      }
      additional_environment_variables = {
        value = jsonencode(jsonencode({
          "DOMAIN_NAME"        = local.identifier
          "AKS_NAMESPACE_NAME" = meshstack_tenant.prod.spec.platform_tenant_id
        }))
      }
    }
  }
}

# Migrate the app-team-managed child building blocks from the deprecated
# meshstack_building_block_v2 resource to meshstack_building_block in place —
# no destroy/recreate of the live blocks.
moved {
  from = meshstack_building_block_v2.repo
  to   = meshstack_building_block.repo
}

moved {
  from = meshstack_building_block_v2.github_actions_dev
  to   = meshstack_building_block.github_actions_dev
}

moved {
  from = meshstack_building_block_v2.github_actions_prod
  to   = meshstack_building_block.github_actions_prod
}
