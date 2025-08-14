locals {
  # Create a purely alphanumeric identifier from the display name
  # Remove special characters, convert to lowercase, and replace spaces/hyphens with nothing
  identifier = lower(replace(replace(var.name, "/[^a-zA-Z0-9\\s\\-\\_]/", ""), "/[\\s\\-\\_]+/", "-"))
}

resource "meshstack_project" "dev" {
  metadata = {
    name               = "${local.identifier}-dev"
    owned_by_workspace = var.workspace_identifier
  }
  spec = {
    display_name = "${var.name} Dev"
    tags         = {}
  }
}

resource "meshstack_project" "prod" {
  metadata = {
    name               = "${local.identifier}-prod"
    owned_by_workspace = var.workspace_identifier
  }
  spec = {
    display_name = "${var.name} Prod"
    tags         = {}
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
        value_string = local.identifier
      }
      repo_owner = {
        value_string = var.repo_admin != null ? var.repo_admin : ""
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

# We need to fetch both dev&prod tenant data after creation to get the platform tenant ID
data "meshstack_tenant_v4" "aks-dev" {
  metadata = {
    uuid = meshstack_tenant_v4.dev.metadata.uuid
  }
}

data "meshstack_tenant_v4" "aks-prod" {
  metadata = {
    uuid = meshstack_tenant_v4.prod.metadata.uuid
  }
}

resource "meshstack_building_block_v2" "github_actions_dev" {
  depends_on = [meshstack_building_block_v2.repo, meshstack_tenant_v4.dev]

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
          "AKS_NAMESPACE_NAME" = data.meshstack_tenant_v4.aks-dev.spec.platform_tenant_id
        })
      }
    }
  }
}

resource "meshstack_building_block_v2" "github_actions_prod" {
  depends_on = [meshstack_building_block_v2.repo, meshstack_building_block_v2.github_actions_dev]

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
          "AKS_NAMESPACE_NAME" = data.meshstack_tenant_v4.aks-prod.spec.platform_tenant_id
        })
      }
    }
  }
}
