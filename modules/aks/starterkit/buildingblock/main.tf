locals {
  # Create a purely alphanumeric identifier from the display name
  # Remove special characters, convert to lowercase, and replace spaces/hyphens with nothing
  identifier = lower(replace(replace(var.name, "/[^a-zA-Z0-9\\s\\-\\_]/", ""), "/[\\s\\-\\_]+/", "-"))

  repo_name = "${local.identifier}-${random_id.repo_suffix.hex}"

  # GitHub Actions environment name per stage. Indexed by stage key (fails on an unknown stage).
  github_environment_names = {
    dev  = "development"
    prod = "production"
  }
}

# Generate a random suffix for the repository name to ensure uniqueness
resource "random_id" "repo_suffix" {
  byte_length = 4 // 8 hex characters
}

resource "meshstack_project" "this" {
  for_each = var.landing_zone_refs

  metadata = {
    name               = "${local.identifier}-${each.key}"
    owned_by_workspace = var.workspace_identifier
  }
  spec = {
    display_name = "${var.name} ${title(each.key)}"
    tags = merge(
      var.project_tags[each.key],
      var.project_tags.owner_tag_key == null ? {} : {
        (var.project_tags.owner_tag_key) : [var.creator.displayName]
      }
    )
  }
}

resource "meshstack_project_user_binding" "creator_admin" {
  for_each = var.creator.type == "User" && var.creator.username != null ? var.landing_zone_refs : {}

  metadata = {
    name = uuid()
  }

  role_ref = {
    name = "Project Admin"
  }

  target_ref = {
    owned_by_workspace = var.workspace_identifier
    name               = meshstack_project.this[each.key].metadata.name
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

resource "meshstack_tenant" "this" {
  for_each = var.landing_zone_refs

  metadata = {
    owned_by_workspace = var.workspace_identifier
    owned_by_project   = meshstack_project.this[each.key].metadata.name
  }

  spec = {
    platform_ref     = var.platform_ref
    landing_zone_ref = var.landing_zone_refs[each.key]
  }

  depends_on = [meshstack_project_user_binding.creator_admin]
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

resource "meshstack_building_block" "github_actions" {
  for_each = var.landing_zone_refs

  spec = {
    building_block_definition_version_ref = {
      uuid = var.github_actions_connector_definition_version_uuid
    }
    target_ref = {
      kind = "meshTenant"
      uuid = meshstack_tenant.this[each.key].metadata.uuid
    }
    display_name = "GHA Connector ${title(each.key)}"
    parent_building_blocks = [{
      buildingblock_uuid = meshstack_building_block.repo.metadata.uuid
      definition_uuid    = var.github_repo_definition_uuid
    }]
    inputs = {
      github_environment_name = {
        value = jsonencode(local.github_environment_names[each.key])
      }
      additional_environment_variables = {
        value = jsonencode(jsonencode({
          "DOMAIN_NAME"        = each.key == "prod" ? local.identifier : "${local.identifier}-${each.key}"
          "AKS_NAMESPACE_NAME" = meshstack_tenant.this[each.key].spec.platform_tenant_id
        }))
      }
    }
  }
}

# --- State address migrations (no resource recreation) ---
# The moves are chained: hop 1 is the resource-type migration (meshTenant v4 GA rename;
# meshstack_building_block_v2 -> meshstack_building_block), hop 2 is this PR's dev/prod -> for_each
# address change. Terraform follows the chain, so a deployed meshstack_tenant_v4.dev migrates
# v4 -> GA -> for_each in sequence without recreation.

# Hop 1 — resource-type migrations.
# Anticipates terraform-provider-meshstack v0.24.0 (#226): meshstack_tenant runs on the meshTenant
# v4 API (shares the v4 body with meshstack_tenant_v4, so the move upgrades state in place).
moved {
  from = meshstack_tenant_v4.dev
  to   = meshstack_tenant.dev
}
moved {
  from = meshstack_tenant_v4.prod
  to   = meshstack_tenant.prod
}
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

# Hop 2 — spelled-out dev/prod -> for_each keys (this refactor). Projects and bindings have no
# hop-1 migration, so their move is the only hop.
moved {
  from = meshstack_tenant.dev
  to   = meshstack_tenant.this["dev"]
}
moved {
  from = meshstack_tenant.prod
  to   = meshstack_tenant.this["prod"]
}
moved {
  from = meshstack_project.dev
  to   = meshstack_project.this["dev"]
}
moved {
  from = meshstack_project.prod
  to   = meshstack_project.this["prod"]
}
moved {
  from = meshstack_project_user_binding.creator_dev_admin[0]
  to   = meshstack_project_user_binding.creator_admin["dev"]
}
moved {
  from = meshstack_project_user_binding.creator_prod_admin[0]
  to   = meshstack_project_user_binding.creator_admin["prod"]
}
moved {
  from = meshstack_building_block.github_actions_dev
  to   = meshstack_building_block.github_actions["dev"]
}
moved {
  from = meshstack_building_block.github_actions_prod
  to   = meshstack_building_block.github_actions["prod"]
}
