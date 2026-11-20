locals {
  imports = var.imports != null ? var.imports : {
    project                = null
    adopt_ske              = false
    git                    = null
    dns                    = null
    adopt_ingress          = false
    secrets_manager        = null
    container_registry     = null
    kubernetes_platform    = null
    starterkit_definitions = null
  }

  # Unset keys are left out, so adding a key to `imports` leaves the nested input unchanged.
  platform_imports = { for key, adopted in local.imports : key => adopted if key != "project" && adopted != null && adopted != false }

  project_import_ids = local.imports.project == null ? toset([]) : toset(["${var.workspace}.${local.project_identifier}"])

  stackit_project_import_ids = data.meshstack_building_blocks.stackit_project == null ? toset([]) : toset(data.meshstack_building_blocks.stackit_project.building_blocks[*].metadata.uuid)

  admin_binding_imports = local.imports.project == null ? {} : local.imports.project.admin_bindings
}

# A tenant created while STACKIT Project was a mandatory block of its landing zone has the block
# already, so it is adopted rather than ordered twice. The filters must be known at plan time, also
# for a tenant created in this run; the definition serves this platform only, and a project has one
# tenant on it. A playground's generated project identifier is unknown until its suffix exists.
data "meshstack_building_blocks" "stackit_project" {
  workspace_identifier = var.workspace
  project_identifier   = local.project_identifier
  definition_uuid      = var.landingzone.project_bbd_ref.uuid

  lifecycle {
    enabled = !var.playground_mode || local.overrides.project_identifier != null

    postcondition {
      condition     = length(self.building_blocks) <= 1
      error_message = "Project ${local.project_identifier} has ${length(self.building_blocks)} STACKIT Project building blocks; delete all but the one its tenant's Platform Tenant ID came from."
    }
  }
}

# The tenant import id names the platform by its identifier, while the landing zone refs carry only
# its uuid.
data "meshstack_platform" "landingzone" {
  lifecycle {
    enabled = local.imports.project != null
  }

  metadata = {
    uuid = var.landingzone.platform_ref.uuid
  }
}

import {
  for_each = local.release_imports_on_destroy ? toset([]) : local.project_import_ids
  to       = module.project.meshstack_project.this
  id       = each.value
}

import {
  for_each = local.release_imports_on_destroy ? local.project_import_ids : toset([])
  to       = module.project.meshstack_project.released
  id       = each.value
}

import {
  for_each = local.release_imports_on_destroy ? toset([]) : local.project_import_ids
  to       = module.tenant.meshstack_tenant.this
  id       = "${each.value}.${data.meshstack_platform.landingzone.identifier}"
}

import {
  for_each = local.release_imports_on_destroy ? local.project_import_ids : toset([])
  to       = module.tenant.meshstack_tenant.released
  id       = "${each.value}.${data.meshstack_platform.landingzone.identifier}"
}

import {
  for_each = local.release_imports_on_destroy ? {} : local.admin_binding_imports
  to       = module.project_admin_bindings.meshstack_project_user_binding.this[each.key]
  id       = each.value
}

import {
  for_each = local.release_imports_on_destroy ? local.admin_binding_imports : {}
  to       = module.project_admin_bindings.meshstack_project_user_binding.released[each.key]
  id       = each.value
}

import {
  for_each = local.release_imports_on_destroy ? toset([]) : local.stackit_project_import_ids
  to       = module.stackit_project.meshstack_building_block.this
  id       = each.value
}

import {
  for_each = local.release_imports_on_destroy ? local.stackit_project_import_ids : toset([])
  to       = module.stackit_project.meshstack_building_block.released
  id       = each.value
}
