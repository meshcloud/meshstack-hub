resource "meshstack_building_block_v2" "git_repository" {
  spec = {
    building_block_definition_version_ref = var.building_block_definition_version_refs["git-repository"]

    display_name = "${var.name} Git Repo"
    target_ref = {
      kind       = "meshWorkspace"
      identifier = var.workspace_identifier
    }

    inputs = {
      # TODO complete the inputs here for template source from backplane
      # Examples how inputs can be defined depending on type
      # flag              = { value_bool = true }
      # num               = { value_int = 1 }
      # text              = { value_string = "Hello, World!" }
      # sensitive_text    = { value_string = "Hidden value" }
      # single_select     = { value_single_select = "single1" }
      # multi_select      = { value_multi_select = ["multi1", "multi2"] }
      # multi_select_json = { value_multi_select = ["multi2", "multi1"] }

      name = { value_string = var.name }
    }
  }
  wait_for_completion = true
}

resource "meshstack_project" "this" {
  for_each = tomap(var.landing_zone_identifiers)
  metadata = {
    name               = "${var.name}-${each.key}"
    owned_by_workspace = var.workspace_identifier
  }
  spec = {
    display_name = "${var.name} ${title(each.key)}"
    tags         = var.project_tags[each.key]
  }
}

resource "meshstack_project_user_binding" "creator_to_admin" {
  for_each = var.creator.type == "User" && var.creator.username != null ? tomap(var.landing_zone_identifiers) : {}

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
}
