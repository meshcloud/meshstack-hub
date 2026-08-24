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
      })
    })
  })
  nullable = false
}

# Variant selector. This is a root variable rather than a `test_context` field because it changes
# the BBD implementation this module builds (sync vs async apply/destroy workflows), which makes it
# a property of the test case, not of the environment the case runs in. Each `tests/*.tftest.hcl`
# file pins it in a file-level `variables` block, so `tofu test` covers both variants in one run.
variable "github_async" {
  type        = bool
  default     = false
  description = "Exercise the async GitHub workflow variant (meshStack run-token callback) instead of the sync one."
}

locals {
  execution_mode = var.github_async ? "async" : "sync"
}

module "github_workflow" {
  source = "../"

  github_owner               = var.test_context.fixtures.github.owner
  github_app_id              = var.test_context.fixtures.github.app_id
  github_app_installation_id = var.test_context.fixtures.github.app_installation_id
  github_app_private_key     = var.test_context.fixtures.github.app_private_key
  github_repository          = var.test_context.fixtures.github.repository
  github_branch              = var.test_context.fixtures.github.branch
  github_async               = var.github_async

  # A non-null value opts the building block definition into destroy automation; the module itself
  # picks the sync or async destroy workflow file based on `github_async`.
  github_destroy_workflow = "destroy.yml"

  meshstack = {
    owning_workspace_identifier = var.test_context.workspace
    tags                        = {}
  }

  hub = {
    git_ref   = var.test_context.hub_git_ref
    bbd_draft = true
  }
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
