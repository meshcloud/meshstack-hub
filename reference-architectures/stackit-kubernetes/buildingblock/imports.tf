locals {
  imports = var.imports != null ? var.imports : { project = null, ske = null, git = null }

  project_import_ids = local.imports.project == null ? toset([]) : toset(["${var.workspace}.${local.project_identifier}"])
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
