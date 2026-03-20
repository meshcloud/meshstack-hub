resource "random_string" "name_suffix" {
  length  = 5
  upper   = false
  numeric = false
  special = false
}

locals {
  name = var.add_random_name_suffix ? "${var.name}-${random_string.name_suffix.result}" : var.name

  app_hostnames = {
    for stage, _ in var.landing_zone_identifiers :
    stage => (
      stage == "prod"
      ? "${local.name}.${var.dns_zone_name}"
      : "${local.name}-${stage}.${var.dns_zone_name}"
    )
  }
}

resource "meshstack_building_block_v2" "git_repository" {
  spec = {
    building_block_definition_version_ref = var.building_block_definitions["git-repository"].version_ref # provisioned in backplane

    display_name = "Git Repo ${local.name}"
    target_ref = {
      kind       = "meshWorkspace"
      identifier = var.workspace_identifier
    }

    inputs = {
      name       = { value_string = local.name }
      clone_addr = { value_string = var.repo_clone_addr }
    }
  }
  wait_for_completion = true
}

resource "meshstack_project" "this" {
  for_each = tomap(var.landing_zone_identifiers)
  metadata = {
    name               = "${local.name}-${each.key}"
    owned_by_workspace = var.workspace_identifier
  }
  spec = {
    display_name = "${var.name} ${title(each.key)}"
    tags = merge(
      var.project_tags[each.key],
      var.project_tags.owner_tag_key == null ? {} : {
        (var.project_tags.owner_tag_key) : [var.creator.displayName]
    })
  }
}

resource "random_uuid" "binding" {
  for_each = var.creator.type == "User" && var.creator.username != null ? tomap(var.landing_zone_identifiers) : {}
}

resource "meshstack_project_user_binding" "creator_to_admin" {
  for_each = var.creator.type == "User" && var.creator.username != null ? tomap(var.landing_zone_identifiers) : {}

  metadata = {
    name = random_uuid.binding[each.key].result
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

resource "meshstack_tenant_v4" "this" {
  for_each = tomap(var.landing_zone_identifiers)

  metadata = {
    owned_by_workspace = var.workspace_identifier
    owned_by_project   = meshstack_project.this[each.key].metadata.name
  }

  spec = {
    platform_identifier     = var.full_platform_identifier
    landing_zone_identifier = each.value
  }

  # FIXME: remove after BD-2288 is fixed
  depends_on = [meshstack_project_user_binding.creator_to_admin]
}

resource "meshstack_building_block_v2" "forgejo_connector" {
  for_each = meshstack_tenant_v4.this

  spec = {
    building_block_definition_version_ref = var.building_block_definitions["forgejo-connector"].version_ref

    display_name = "Forgejo Connector ${title(each.key)}"
    target_ref = {
      kind = "meshTenant"
      uuid = each.value.metadata.uuid
    }

    parent_building_blocks = [{
      buildingblock_uuid = meshstack_building_block_v2.git_repository.metadata.uuid
      definition_uuid    = var.building_block_definitions["git-repository"].uuid
    }]

    inputs = {
      stage        = { value_string = each.key }
      app_hostname = { value_string = local.app_hostnames[each.key] }
    }
  }

  wait_for_completion = true
}

