locals {
  identifier          = lower(replace(replace(var.name, "/[^a-zA-Z0-9\\s\\-\\_]/", ""), "/[\\s\\-\\_]+/", "-"))
  project_tags_config = yamldecode(var.project_tags_yaml)
  repo_name           = "${local.identifier}-${random_id.repo_suffix.hex}"
}

resource "random_id" "repo_suffix" {
  byte_length = 4
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

resource "meshstack_building_block_v2" "git_repo" {
  spec = {
    building_block_definition_version_ref = {
      uuid = var.git_repo_definition_version_uuid
    }

    display_name = local.identifier
    target_ref = {
      kind       = "meshWorkspace"
      identifier = var.workspace_identifier
    }

    inputs = {
      repository_name = {
        value_string = local.repo_name
      }
      repository_description = {
        value_string = "Application repository for ${var.name}"
      }
      repository_private = {
        value_bool = true
      }
      use_template = {
        value_bool = false
      }
    }
  }
}

resource "meshstack_building_block_v2" "forgejo_connector_dev" {
  spec = {
    building_block_definition_version_ref = {
      uuid = var.forgejo_connector_definition_version_uuid
    }
    target_ref = {
      kind = "meshTenant"
      uuid = meshstack_tenant_v4.dev.metadata.uuid
    }
    display_name = "Forgejo Connector Dev"
    parent_building_blocks = [{
      buildingblock_uuid = meshstack_building_block_v2.git_repo.metadata.uuid
      definition_uuid    = var.git_repo_definition_uuid
    }]
  }
}

resource "meshstack_building_block_v2" "forgejo_connector_prod" {
  depends_on = [meshstack_building_block_v2.forgejo_connector_dev]

  spec = {
    building_block_definition_version_ref = {
      uuid = var.forgejo_connector_definition_version_uuid
    }
    target_ref = {
      kind = "meshTenant"
      uuid = meshstack_tenant_v4.prod.metadata.uuid
    }
    display_name = "Forgejo Connector Prod"
    parent_building_blocks = [{
      buildingblock_uuid = meshstack_building_block_v2.git_repo.metadata.uuid
      definition_uuid    = var.git_repo_definition_uuid
    }]
  }
}
