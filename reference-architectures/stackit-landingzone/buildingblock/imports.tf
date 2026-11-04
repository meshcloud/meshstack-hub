locals {
  imports = var.imports != null ? var.imports : {
    folder                                = null
    foundation_project                    = null
    adopt_platform                        = false
    project_definition                    = null
    service_account_definition            = null
    service_account_federation_definition = null
  }

  # Spelled out because the location resource's own name would defer the platform lookup to apply.
  adopted_location_name = var.use_global_location ? "global" : local.platform_identifier

  adopted_landingzone_variants = concat(["default"], local.network_enabled ? ["networked"] : [])

  adopted_foundation_project_id = local.imports.foundation_project == null ? null : data.stackit_resourcemanager_project.adopted.project_id

  adopted_definitions = {
    for key in ["project_definition", "service_account_definition", "service_account_federation_definition"] : key => local.imports[key]
    if local.imports[key] != null
  }

  # Keyed like the backplane's providers, by the index of the subject they trust.
  adopted_federated_identity_providers = {
    for key in ["project_definition", "service_account_definition", "service_account_federation_definition"] : key => local.imports[key] == null ? {} : {
      for index, id in local.imports[key].federated_identity_provider_ids : tostring(index) => "${local.adopted_foundation_project_id},${local.imports[key].service_account_email},${id}"
    }
  }
}

import {
  for_each = local.imports.folder == null ? {} : { this = local.imports.folder }
  to       = stackit_resourcemanager_folder.this
  id       = each.value.container_id
}

import {
  for_each = local.imports.foundation_project == null ? {} : { this = local.imports.foundation_project }
  to       = stackit_resourcemanager_project.foundation
  id       = each.value.container_id
}

data "stackit_resourcemanager_project" "adopted" {
  lifecycle {
    enabled = local.imports.foundation_project != null
  }

  container_id = local.imports.foundation_project == null ? null : local.imports.foundation_project.container_id
}

import {
  for_each = local.imports.adopt_platform && !var.use_global_location ? toset([local.platform_identifier]) : toset([])
  to       = meshstack_location.this
  id       = each.value
}

# Owner and type force a replacement, which would delete the platform with its tenants, so the
# lookup fails unless both match.
data "meshstack_platforms" "adopted" {
  lifecycle {
    enabled = local.imports.adopt_platform

    postcondition {
      condition     = length(self.platforms) == 1
      error_message = "imports.adopt_platform: workspace ${var.workspace} owns no STACKIT platform ${local.platform_identifier}.${local.adopted_location_name}."
    }
  }

  identifier               = "${local.platform_identifier}.${local.adopted_location_name}"
  owned_by_workspace       = var.workspace
  platform_type_identifier = "STACKIT"
}

import {
  for_each = local.imports.adopt_platform ? toset([local.platform_identifier]) : toset([])
  to       = module.stackit_integration.meshstack_platform.this
  id       = one(data.meshstack_platforms.adopted.platforms).metadata.uuid
}

import {
  for_each = local.imports.adopt_platform ? toset(local.adopted_landingzone_variants) : toset([])
  to       = module.stackit_integration.meshstack_landingzone.this[each.key]
  id       = "${local.platform_identifier}-${each.key}"
}

# Owner and target type force a replacement, which would delete the definition with its building
# blocks, so the lookup fails unless both match.
data "meshstack_building_block_definition" "adopted" {
  for_each = local.adopted_definitions

  metadata = {
    uuid               = each.value.uuid
    owned_by_workspace = var.workspace
  }

  spec = {
    target_type = "TENANT_LEVEL"
  }
}

import {
  for_each = { for key, adopted in local.adopted_definitions : key => adopted if key == "project_definition" }
  to       = module.stackit_integration.meshstack_building_block_definition.this["default"]
  id       = data.meshstack_building_block_definition.adopted[each.key].metadata.uuid
}

import {
  for_each = { for key, adopted in local.adopted_definitions : key => adopted if key == "project_definition" }
  to       = module.stackit_integration.module.backplane.stackit_service_account.building_block
  id       = "${local.adopted_foundation_project_id},${each.value.service_account_email}"
}

import {
  for_each = local.adopted_federated_identity_providers["project_definition"]
  to       = module.stackit_integration.module.backplane.stackit_service_account_federated_identity_provider.building_block[each.key]
  id       = each.value
}

import {
  for_each = { for key, adopted in local.adopted_definitions : key => adopted.service_account_email if key == "project_definition" }
  to       = module.stackit_integration.module.backplane.stackit_authorization_organization_role_assignment.project_admin
  id       = "${var.stackit_org},resource-manager.admin,${each.value}"
}

import {
  for_each = { for key, adopted in local.adopted_definitions : key => adopted.service_account_email if key == "project_definition" && var.role_mapping.organization_onboarding }
  to       = module.stackit_integration.module.backplane.stackit_authorization_organization_role_assignment.member_admin
  id       = "${var.stackit_org},iam.member-admin,${each.value}"
}

import {
  for_each = { for key, adopted in local.adopted_definitions : key => adopted if key == "service_account_definition" }
  to       = module.service_account_integration.meshstack_building_block_definition.this
  id       = data.meshstack_building_block_definition.adopted[each.key].metadata.uuid
}

import {
  for_each = { for key, adopted in local.adopted_definitions : key => adopted if key == "service_account_definition" }
  to       = module.service_account_integration.module.backplane.stackit_service_account.building_block
  id       = "${local.adopted_foundation_project_id},${each.value.service_account_email}"
}

import {
  for_each = local.adopted_federated_identity_providers["service_account_definition"]
  to       = module.service_account_integration.module.backplane.stackit_service_account_federated_identity_provider.building_block[each.key]
  id       = each.value
}

import {
  for_each = { for key, adopted in local.adopted_definitions : key => adopted.service_account_email if key == "service_account_definition" }
  to       = module.service_account_integration.module.backplane.stackit_authorization_organization_role_assignment.service_account_admin
  id       = "${var.stackit_org},iam.service-account-admin,${each.value}"
}

import {
  for_each = { for key, adopted in local.adopted_definitions : key => adopted.service_account_email if key == "service_account_definition" }
  to       = module.service_account_integration.module.backplane.stackit_authorization_organization_role_assignment.member_admin
  id       = "${var.stackit_org},iam.member-admin,${each.value}"
}

import {
  for_each = { for key, adopted in local.adopted_definitions : key => adopted if key == "service_account_federation_definition" }
  to       = module.service_account_federation_integration.meshstack_building_block_definition.this
  id       = data.meshstack_building_block_definition.adopted[each.key].metadata.uuid
}

import {
  for_each = { for key, adopted in local.adopted_definitions : key => adopted if key == "service_account_federation_definition" }
  to       = module.service_account_federation_integration.module.backplane.stackit_service_account.building_block
  id       = "${local.adopted_foundation_project_id},${each.value.service_account_email}"
}

import {
  for_each = local.adopted_federated_identity_providers["service_account_federation_definition"]
  to       = module.service_account_federation_integration.module.backplane.stackit_service_account_federated_identity_provider.building_block[each.key]
  id       = each.value
}
