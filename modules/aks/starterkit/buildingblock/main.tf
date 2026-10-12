locals {
  # Create a purely alphanumeric identifier from the display name
  # Remove special characters, convert to lowercase, and replace spaces/hyphens with nothing
  identifier = lower(replace(replace(var.name, "/[^a-zA-Z0-9\\s\\-\\_]/", ""), "/[\\s\\-\\_]+/", "-"))

  repo_name = "${local.identifier}-${random_id.repo_suffix.hex}"

  # GitHub Actions environment name per stage. Its keys are the stages the starter kit creates a
  # namespace for.
  github_environment_names = {
    dev  = "development"
    prod = "production"
  }

  stages = toset(keys(local.github_environment_names))
}

# Generate a random suffix for the repository name to ensure uniqueness
resource "random_id" "repo_suffix" {
  byte_length = 4 // 8 hex characters
}

resource "meshstack_building_block" "repo" {
  spec = {
    building_block_definition_version_ref = var.building_block_definition_version_refs["git-repository"]

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

  lifecycle {
    postcondition {
      condition     = self.status.status == "SUCCEEDED"
      error_message = "Building block ${self.metadata.uuid} is ${self.status.status}, not SUCCEEDED. See its run in meshPanel."
    }
  }
}

resource "meshstack_building_block" "namespace" {
  for_each = local.stages

  spec = {
    building_block_definition_version_ref = var.building_block_definition_version_refs["aks-namespace"]

    display_name = "${var.name} ${title(each.key)} namespace"
    target_ref = {
      kind = "meshWorkspace"
      name = var.workspace_identifier
    }

    inputs = {
      namespace_name = {
        value = jsonencode("${local.identifier}-${each.key}")
      }
      admin_group_object_ids = {
        value = jsonencode(var.namespace_group_object_ids.admin)
      }
      edit_group_object_ids = {
        value = jsonencode(var.namespace_group_object_ids.edit)
      }
      view_group_object_ids = {
        value = jsonencode(var.namespace_group_object_ids.view)
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

resource "meshstack_building_block" "github_actions" {
  for_each = local.stages

  spec = {
    building_block_definition_version_ref = var.building_block_definition_version_refs["github-actions-connector"]
    target_ref = {
      kind = "meshWorkspace"
      name = var.workspace_identifier
    }
    display_name               = "GHA Connector ${title(each.key)}"
    parent_building_block_refs = [meshstack_building_block.repo.ref, meshstack_building_block.namespace[each.key].ref]
    inputs = {
      github_environment_name = {
        value = jsonencode(local.github_environment_names[each.key])
      }
      additional_environment_variables = {
        value = jsonencode(jsonencode({
          "DOMAIN_NAME"        = each.key == "prod" ? local.identifier : "${local.identifier}-${each.key}"
          "AKS_NAMESPACE_NAME" = jsondecode(meshstack_building_block.namespace[each.key].status.outputs.namespace_name.value)
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
