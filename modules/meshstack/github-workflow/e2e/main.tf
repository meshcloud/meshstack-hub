variable "test_context" {
  type = object({
    hub_git_ref = string
    workspace   = string
    project     = string
    name_suffix = string

    fixtures = object({
      github = object({
        owner               = string
        app_id              = string
        app_installation_id = string
        app_private_key     = string
        repository          = string
        branch              = optional(string, "main")
        apply_workflow      = optional(string, "apply.yml")
        destroy_workflow    = optional(string)
        async               = optional(bool, false)
      })
    })
  })
  nullable = false
}

module "github_workflow" {
  source = "../"

  github_owner               = var.test_context.fixtures.github.owner
  github_app_id              = var.test_context.fixtures.github.app_id
  github_app_installation_id = var.test_context.fixtures.github.app_installation_id
  github_app_private_key     = var.test_context.fixtures.github.app_private_key
  github_repository          = var.test_context.fixtures.github.repository
  github_branch              = var.test_context.fixtures.github.branch
  github_apply_workflow      = var.test_context.fixtures.github.apply_workflow
  github_destroy_workflow    = try(var.test_context.fixtures.github.destroy_workflow, null)
  github_async               = try(var.test_context.fixtures.github.async, false)

  meshstack = {
    owning_workspace_identifier = var.test_context.workspace
    tags                        = {}
  }

  hub = {
    git_ref   = var.test_context.hub_git_ref
    bbd_draft = true
  }
}

locals {
  execution_mode = try(var.test_context.fixtures.github.async, false) ? "async" : "sync"
}

resource "meshstack_building_block" "this" {
  wait_for_completion = true

  spec = {
    building_block_definition_version_ref = module.github_workflow.building_block_definition.version_ref

    display_name = "smoke-test-github-workflow-${local.execution_mode}-${var.test_context.name_suffix}"
    target_ref = {
      kind = "meshWorkspace"
      name = var.test_context.workspace
    }

    inputs = {
      environment = {
        value = jsonencode("dev")
      }
    }
  }
}
