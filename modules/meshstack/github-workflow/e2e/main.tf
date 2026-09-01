variable "test_context" {
  type = object({
    hub_git_ref = string
    workspace   = string
    project     = string
    name_suffix = string

    fixtures = object({
      github = object({
        owner      = string
        repository = string

        # Base branch the per-run ephemeral branch forks from — normally the fixture repository's
        # default branch. Workflow files are NOT committed here; see `github_branch.ephemeral`.
        branch = optional(string, "main")
      })
    })
  })
  nullable = false
}

# Credentials of the GitHub App that the module under test commits with and that this module's own
# provider authenticates as. Root variables rather than `test_context` fields: the runner exports
# every secret as TF_VAR_<name>, so none of them has to travel through the grab-bag.
variable "github_app_id" {
  type     = string
  nullable = false
}

variable "github_app_private_key" {
  type      = string
  sensitive = true
  nullable  = false
}

variable "github_app_installation_id" {
  type     = string
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

  github_repository_name = one(slice(split("/", var.test_context.fixtures.github.repository), 1, 2))

  # The variant is part of the name so a leaked branch is attributable to a run *and* a case, and so
  # a leak can never block the sibling test file later in the same run.
  ephemeral_branch = "e2e/github-workflow-${local.execution_mode}-${var.test_context.name_suffix}"
}

# Per-run ephemeral branch. The backplane's job is to commit workflow files into the target
# repository, so exercising it honestly means those commits really happen — but pointing them at the
# fixture repository's default branch rewrites its history on every run. Giving each case its own
# branch keeps the backplane behaviour under test while confining every commit to a ref that is
# deleted at teardown, so the default branch is never touched.
#
# This lives in the e2e module rather than the backplane on purpose: a real platform team wants the
# workflows on a durable branch they chose. The ephemeral branch is a property of the test.
resource "github_branch" "ephemeral" {
  repository    = local.github_repository_name
  branch        = local.ephemeral_branch
  source_branch = var.test_context.fixtures.github.branch
}

module "github_workflow" {
  source = "../"

  github_owner               = var.test_context.fixtures.github.owner
  github_app_id              = var.github_app_id
  github_app_installation_id = var.github_app_installation_id
  github_app_private_key     = var.github_app_private_key
  github_repository          = var.test_context.fixtures.github.repository
  github_branch              = github_branch.ephemeral.branch
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
  # The delete run dispatches the destroy workflow, which must still exist on the ephemeral branch.
  # Without this, OpenTofu is free to delete the branch in parallel with the delete run.
  depends_on = [module.github_workflow, github_branch.ephemeral]

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
