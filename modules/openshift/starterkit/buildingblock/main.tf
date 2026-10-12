resource "random_string" "name_suffix" {
  length  = 5
  upper   = false
  numeric = false
  special = false
}

locals {
  sanitized_name = lower(replace(replace(var.name, "/[^a-zA-Z0-9\\s\\-]/", ""), "/[\\s]+/", "-"))
  name           = var.add_random_name_suffix ? "${local.sanitized_name}-${random_string.name_suffix.result}" : local.sanitized_name

  app_hostnames = {
    for stage, _ in var.landing_zone_refs :
    stage => stage == "prod" ? "${local.name}.${var.apps_domain}" : "${local.name}-${stage}.${var.apps_domain}"
  }

  # prod deploys from the release branch so a merge gates it; every other stage follows main.
  deploy_branches = {
    for stage, _ in var.landing_zone_refs :
    stage => stage == "prod" ? "release" : "main"
  }

  repo_html_url = jsondecode(meshstack_building_block.repo.status.outputs.repo_html_url.value)
}

resource "meshstack_building_block" "repo" {
  spec = {
    building_block_definition_version_ref = var.building_block_definition_version_refs["git-repository"]

    display_name = "${var.github_org}/${local.name}"
    target_ref = {
      kind = "meshWorkspace"
      name = var.workspace_identifier
    }

    inputs = {
      repo_name       = { value = jsonencode(local.name) }
      repo_owner      = { value = jsonencode(coalesce(var.repo_admin, "null")) }
      repo_visibility = { value = jsonencode("private") }
      use_template    = { value = jsonencode(true) }
      template_owner  = { value = jsonencode(split("/", var.github_template_repo_path)[0]) }
      template_repo   = { value = jsonencode(split("/", var.github_template_repo_path)[1]) }
    }
  }

  lifecycle {
    postcondition {
      condition     = self.status.status == "SUCCEEDED"
      error_message = "Building block ${self.metadata.uuid} is ${self.status.status}, not SUCCEEDED. See its run in meshPanel."
    }
  }
}

resource "meshstack_project" "this" {
  for_each = var.landing_zone_refs

  metadata = {
    name               = "${local.name}-${each.key}"
    owned_by_workspace = var.workspace_identifier
  }
  spec = {
    display_name = "${var.name} ${title(each.key)}"
    tags = merge(
      lookup(var.project_tags.stages, each.key, {}),
      var.project_tags.owner_tag_key == null ? {} : {
        (var.project_tags.owner_tag_key) : [var.creator.displayName]
    })
  }
}

resource "random_uuid" "binding" {
  for_each = var.creator.type == "User" && var.creator.username != null ? var.landing_zone_refs : {}
}

resource "meshstack_project_user_binding" "creator_to_admin" {
  for_each = var.creator.type == "User" && var.creator.username != null ? var.landing_zone_refs : {}

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

resource "meshstack_tenant" "this" {
  for_each = var.landing_zone_refs

  metadata = {
    owned_by_workspace = var.workspace_identifier
    owned_by_project   = meshstack_project.this[each.key].metadata.name
  }

  spec = {
    platform_ref     = var.platform_ref
    landing_zone_ref = each.value
  }

  # Orders the destroy, not the create: deleted in parallel, the tenant and the binding deadlock in
  # meshStack, which does not retry. See the same block in modules/ske/ske-starterkit.
  depends_on = [meshstack_project_user_binding.creator_to_admin]
}

resource "meshstack_building_block" "github_actions" {
  for_each = meshstack_tenant.this

  spec = {
    building_block_definition_version_ref = var.building_block_definition_version_refs["github-actions-connector"]

    display_name               = "GHA Connector ${title(each.key)}"
    target_ref                 = each.value.ref
    parent_building_block_refs = [meshstack_building_block.repo.ref]

    inputs = {
      github_environment_name = { value = jsonencode(each.key) }
      deploy_branch           = { value = jsonencode(local.deploy_branches[each.key]) }
      additional_environment_variables = {
        value = jsonencode(jsonencode({
          APP_HOSTNAME = local.app_hostnames[each.key]
        }))
      }
    }
  }

  lifecycle {
    postcondition {
      condition     = self.status.status == "SUCCEEDED"
      error_message = "Building block ${self.metadata.uuid} is ${self.status.status}, not SUCCEEDED. See its run in meshPanel."
    }
  }
}
