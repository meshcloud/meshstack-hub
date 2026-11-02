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
