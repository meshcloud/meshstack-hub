locals {
  identifier = lower(replace(replace(var.name, "/[^a-zA-Z0-9\\s\\-\\_]/", ""), "/[\\s\\-\\_]+/", "-"))

  project_tags_config = yamldecode(var.project_tags_yaml)
}

resource "random_id" "suffix" {
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

resource "meshstack_building_block_v2" "azdevops_project" {
  spec = {
    building_block_definition_version_ref = {
      uuid = var.azdevops_project_definition_version_uuid
    }

    display_name = "${local.identifier}-aks"
    target_ref = {
      kind       = "meshWorkspace"
      identifier = var.workspace_identifier
    }

    inputs = {
      project_name = {
        value_string = "${local.identifier}-aks-${random_id.suffix.hex}"
      }
      project_description = {
        value_string = "AKS application deployment project for ${var.name}"
      }
      project_visibility = {
        value_string = "private"
      }
    }
  }
}

resource "meshstack_building_block_v2" "repository" {
  spec = {
    building_block_definition_version_ref = {
      uuid = var.azdevops_repository_definition_version_uuid
    }

    display_name = "${local.identifier}-app"
    target_ref = {
      kind       = "meshWorkspace"
      identifier = var.workspace_identifier
    }

    parent_building_blocks = [{
      buildingblock_uuid = meshstack_building_block_v2.azdevops_project.metadata.uuid
      definition_uuid    = var.azdevops_project_definition_uuid
    }]

    inputs = {
      repository_name = {
        value_string = "${local.identifier}-app"
      }
      init_type = {
        value_string = var.repository_init_type
      }
      enable_branch_policies = {
        value_bool = var.enable_branch_policies
      }
      minimum_reviewers = {
        value_number = var.minimum_reviewers
      }
    }
  }
}

resource "meshstack_building_block_v2" "service_connection_dev" {
  spec = {
    building_block_definition_version_ref = {
      uuid = var.azdevops_service_connection_definition_version_uuid
    }

    display_name = "Azure AKS Dev Connection"
    target_ref = {
      kind = "meshTenant"
      uuid = meshstack_tenant_v4.dev.metadata.uuid
    }

    parent_building_blocks = [{
      buildingblock_uuid = meshstack_building_block_v2.azdevops_project.metadata.uuid
      definition_uuid    = var.azdevops_project_definition_uuid
    }]

    inputs = {
      service_connection_name = {
        value_string = "Azure-AKS-Dev"
      }
      description = {
        value_string = "Service connection for AKS development environment"
      }
      azure_subscription_id = {
        value_string = var.dev_azure_subscription_id
      }
      service_principal_id = {
        value_string = var.dev_service_principal_id
      }
      application_object_id = {
        value_string = var.dev_application_object_id
      }
      azure_tenant_id = {
        value_string = var.azure_tenant_id
      }
      authorize_all_pipelines = {
        value_bool = true
      }
    }
  }
}

resource "meshstack_building_block_v2" "service_connection_prod" {
  spec = {
    building_block_definition_version_ref = {
      uuid = var.azdevops_service_connection_definition_version_uuid
    }

    display_name = "Azure AKS Prod Connection"
    target_ref = {
      kind = "meshTenant"
      uuid = meshstack_tenant_v4.prod.metadata.uuid
    }

    parent_building_blocks = [{
      buildingblock_uuid = meshstack_building_block_v2.azdevops_project.metadata.uuid
      definition_uuid    = var.azdevops_project_definition_uuid
    }]

    inputs = {
      service_connection_name = {
        value_string = "Azure-AKS-Prod"
      }
      description = {
        value_string = "Service connection for AKS production environment"
      }
      azure_subscription_id = {
        value_string = var.prod_azure_subscription_id
      }
      service_principal_id = {
        value_string = var.prod_service_principal_id
      }
      application_object_id = {
        value_string = var.prod_application_object_id
      }
      azure_tenant_id = {
        value_string = var.azure_tenant_id
      }
      authorize_all_pipelines = {
        value_bool = false
      }
    }
  }
}

resource "meshstack_building_block_v2" "pipeline_dev" {
  spec = {
    building_block_definition_version_ref = {
      uuid = var.azdevops_pipeline_definition_version_uuid
    }

    display_name = "Deploy to Dev"
    target_ref = {
      kind = "meshTenant"
      uuid = meshstack_tenant_v4.dev.metadata.uuid
    }

    parent_building_blocks = [
      {
        buildingblock_uuid = meshstack_building_block_v2.repository.metadata.uuid
        definition_uuid    = var.azdevops_repository_definition_uuid
      },
      {
        buildingblock_uuid = meshstack_building_block_v2.service_connection_dev.metadata.uuid
        definition_uuid    = var.azdevops_service_connection_definition_uuid
      }
    ]

    inputs = {
      pipeline_name = {
        value_string = "Deploy to Dev"
      }
      branch_name = {
        value_string = "refs/heads/main"
      }
      yaml_path = {
        value_string = "azure-pipelines-dev.yml"
      }
      pipeline_variables = {
        value_code = jsonencode([
          {
            name  = "AKS_NAMESPACE"
            value = meshstack_tenant_v4.dev.spec.platform_tenant_id
          },
          {
            name  = "ENVIRONMENT"
            value = "development"
          },
          {
            name  = "SERVICE_CONNECTION"
            value = "Azure-AKS-Dev"
          },
          {
            name  = "DOMAIN_NAME"
            value = "${local.identifier}-dev"
          }
        ])
      }
    }
  }
}

resource "meshstack_building_block_v2" "pipeline_prod" {
  depends_on = [meshstack_building_block_v2.pipeline_dev]

  spec = {
    building_block_definition_version_ref = {
      uuid = var.azdevops_pipeline_definition_version_uuid
    }

    display_name = "Deploy to Prod"
    target_ref = {
      kind = "meshTenant"
      uuid = meshstack_tenant_v4.prod.metadata.uuid
    }

    parent_building_blocks = [
      {
        buildingblock_uuid = meshstack_building_block_v2.repository.metadata.uuid
        definition_uuid    = var.azdevops_repository_definition_uuid
      },
      {
        buildingblock_uuid = meshstack_building_block_v2.service_connection_prod.metadata.uuid
        definition_uuid    = var.azdevops_service_connection_definition_uuid
      }
    ]

    inputs = {
      pipeline_name = {
        value_string = "Deploy to Prod"
      }
      branch_name = {
        value_string = "refs/heads/release"
      }
      yaml_path = {
        value_string = "azure-pipelines-prod.yml"
      }
      pipeline_variables = {
        value_code = jsonencode([
          {
            name  = "AKS_NAMESPACE"
            value = meshstack_tenant_v4.prod.spec.platform_tenant_id
          },
          {
            name  = "ENVIRONMENT"
            value = "production"
          },
          {
            name  = "SERVICE_CONNECTION"
            value = "Azure-AKS-Prod"
          },
          {
            name  = "DOMAIN_NAME"
            value = local.identifier
          }
        ])
      }
    }
  }
}
