locals {
  adopt_platform = local.kubernetes_platform_imports.platform_name != null

  adopted_landingzone_names = {
    for stage, name in local.kubernetes_platform_imports.landingzone_names : stage => name
    if contains(keys(var.stages), stage)
  }

  # An adopted platform's location exists already, and naming it here keeps the lookup in the plan.
  adopted_location_name = coalesce(local.kubernetes_platform_imports.location_name, "global")

  adopted_platform_uuid = local.adopt_platform ? one(data.meshstack_platforms.adopted.platforms).metadata.uuid : null
}

# Matching on owner and type as well keeps the import from planning a replacement, which would
# delete the platform with its tenants.
data "meshstack_platforms" "adopted" {
  lifecycle {
    enabled = local.adopt_platform

    postcondition {
      condition     = length(self.platforms) == 1
      error_message = "imports.kubernetes_platform names no KUBERNETES platform ${local.platform_name}.${local.adopted_location_name} that workspace ${var.workspace} owns."
    }
  }

  identifier               = "${local.platform_name}.${local.adopted_location_name}"
  owned_by_workspace       = var.workspace
  platform_type_identifier = "KUBERNETES"
}

data "meshstack_landingzones" "adopted" {
  lifecycle {
    enabled = length(local.adopted_landingzone_names) > 0

    postcondition {
      condition     = length(setsubtract(values(local.adopted_landingzone_names), [for lz in self.landing_zones : lz.metadata.name])) == 0
      error_message = "imports.kubernetes_platform.landingzone_names names a landing zone that is not on the adopted platform or that workspace ${var.workspace} does not own."
    }
  }

  platform_uuid      = local.adopted_platform_uuid
  owned_by_workspace = var.workspace
}

import {
  for_each = local.adopt_platform ? toset([local.platform_name]) : toset([])
  to       = module.kubernetes_integration.meshstack_platform.this
  id       = local.adopted_platform_uuid
}

import {
  for_each = local.adopted_landingzone_names
  to       = module.kubernetes_integration.meshstack_landingzone.this[each.key]
  id       = each.value
}

locals {
  # The definitions are registered only in phase 2.
  adopted_starterkit_definitions = var.phase2_completed && var.imports.starterkit_definitions != null ? {
    for key, uuid in var.imports.starterkit_definitions : key => uuid if uuid != null
  } : {}

  starterkit_definition_target_types = {
    starterkit        = "WORKSPACE_LEVEL"
    git_repository    = "WORKSPACE_LEVEL"
    forgejo_connector = "TENANT_LEVEL"
  }
}

# Owner and target type force a replacement, which would delete the definition with its building
# blocks, so the lookup fails unless both match. The import then adds a version to the definition.
data "meshstack_building_block_definition" "adopted" {
  for_each = local.adopted_starterkit_definitions

  metadata = {
    uuid               = each.value
    owned_by_workspace = var.workspace
  }

  spec = {
    target_type = local.starterkit_definition_target_types[each.key]
  }
}

import {
  for_each = { for key, uuid in local.adopted_starterkit_definitions : key => uuid if key == "starterkit" }
  to       = module.ske_starterkit_integration.meshstack_building_block_definition.this
  id       = data.meshstack_building_block_definition.adopted[each.key].metadata.uuid
}

import {
  for_each = { for key, uuid in local.adopted_starterkit_definitions : key => uuid if key == "git_repository" }
  to       = module.git_repository_integration.meshstack_building_block_definition.this
  id       = data.meshstack_building_block_definition.adopted[each.key].metadata.uuid
}

import {
  for_each = { for key, uuid in local.adopted_starterkit_definitions : key => uuid if key == "forgejo_connector" }
  to       = module.forgejo_connector_integration.meshstack_building_block_definition.this
  id       = data.meshstack_building_block_definition.adopted[each.key].metadata.uuid
}
