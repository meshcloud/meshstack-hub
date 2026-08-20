variable "test_context" {
  type = object({
    hub_git_ref = string
    workspace   = string
    name_suffix = string

    # Mode discriminator: set in foundation mode to order an already-deployed BBD version;
    # null in build-from-source mode, which builds the BBD from hub source.
    bbd_version_ref = optional(object({
      uuid = string
    }))

    # Only needed in build-from-source mode: the GitHub App credentials the integration wires
    # into the BBD as static (environment) inputs. This building block is workspace-level, so
    # foundation mode needs no fixtures at all.
    fixtures = optional(object({
      github = object({
        owner               = string
        app_id              = string
        app_installation_id = string
        app_private_key     = string
      })
    }))
  })
  nullable = false
}

module "github_repository" {
  count  = var.test_context.bbd_version_ref == null ? 1 : 0
  source = "../"

  github = {
    org                 = var.test_context.fixtures.github.owner
    app_id              = var.test_context.fixtures.github.app_id
    app_installation_id = var.test_context.fixtures.github.app_installation_id
    app_pem_file        = var.test_context.fixtures.github.app_private_key
  }

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
  version_ref = var.test_context.bbd_version_ref != null ? var.test_context.bbd_version_ref : module.github_repository[0].building_block_definition.version_ref
}

resource "meshstack_building_block" "this" {
  depends_on          = [module.github_repository]
  wait_for_completion = true

  spec = {
    building_block_definition_version_ref = { uuid = local.version_ref.uuid }

    display_name = "smoke-test-github-repository-hub-${var.test_context.name_suffix}"
    target_ref = {
      kind = "meshWorkspace"
      name = var.test_context.workspace
    }

    inputs = {
      repo_name        = { value = jsonencode("smoke-test-github-repository-${var.test_context.name_suffix}") }
      repo_description = { value = jsonencode("Ephemeral repository created by the hub e2e smoke test.") }
      repo_visibility  = { value = jsonencode("private") }

      # The default archives instead of deleting. A smoke test that runs on a schedule must not
      # accumulate archived repositories in the owning organization, so opt into deletion.
      archive_repo_on_destroy = { value = jsonencode(false) }
    }
  }
}
