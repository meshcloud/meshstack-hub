locals {
  identifier          = lower(replace(replace(var.name, "/[^a-zA-Z0-9\\s\\-\\_]/", ""), "/[\\s\\-\\_]+/", "-"))
  project_tags_config = yamldecode(var.project_tags_yaml)
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
    platform_identifier     = var.platform_identifier
    landing_zone_identifier = var.landing_zone_dev_identifier
  }
}

resource "meshstack_tenant_v4" "prod" {
  metadata = {
    owned_by_workspace = var.workspace_identifier
    owned_by_project   = meshstack_project.prod.metadata.name
  }

  spec = {
    platform_identifier     = var.platform_identifier
    landing_zone_identifier = var.landing_zone_prod_identifier
  }
}

resource "meshstack_building_block_v2" "entitlements_dev" {
  spec = {
    building_block_definition_version_ref = {
      uuid = var.entitlements_definition_version_uuid
    }

    display_name = "${var.name} Dev Entitlements"
    target_ref = {
      kind = "meshTenant"
      uuid = meshstack_tenant_v4.dev.metadata.uuid
    }

    inputs = {
      entitlements = {
        value_string = var.entitlements
      }
    }
  }
}

resource "meshstack_building_block_v2" "entitlements_prod" {
  spec = {
    building_block_definition_version_ref = {
      uuid = var.entitlements_definition_version_uuid
    }

    display_name = "${var.name} Prod Entitlements"
    target_ref = {
      kind = "meshTenant"
      uuid = meshstack_tenant_v4.prod.metadata.uuid
    }

    inputs = {
      entitlements = {
        value_string = var.entitlements
      }
    }
  }
}

resource "meshstack_building_block_v2" "cloudfoundry_dev" {
  count = var.enable_cloudfoundry ? 1 : 0

  spec = {
    building_block_definition_version_ref = {
      uuid = var.cloudfoundry_definition_version_uuid
    }

    display_name = "${var.name} Dev Cloud Foundry"
    target_ref = {
      kind = "meshTenant"
      uuid = meshstack_tenant_v4.dev.metadata.uuid
    }

    inputs = {
      cloudfoundry_plan = {
        value_string = var.cloudfoundry_plan
      }
      cf_services = {
        value_string = var.cf_services_dev
      }
    }
  }
}

resource "meshstack_building_block_v2" "cloudfoundry_prod" {
  count = var.enable_cloudfoundry ? 1 : 0

  spec = {
    building_block_definition_version_ref = {
      uuid = var.cloudfoundry_definition_version_uuid
    }

    display_name = "${var.name} Prod Cloud Foundry"
    target_ref = {
      kind = "meshTenant"
      uuid = meshstack_tenant_v4.prod.metadata.uuid
    }

    inputs = {
      cloudfoundry_plan = {
        value_string = var.cloudfoundry_plan
      }
      cf_services = {
        value_string = var.cf_services_prod
      }
    }
  }
}
