variable "test_context" {
  type = object({
    hub_git_ref = string
    workspace   = string
    run_id      = string

    fixtures = object({
      stackit = object({
        project_id = string
      })
    })
  })
  nullable = false
}

provider "stackit" {
  # Credentials come from the environment, WIF in CI. `iam` is needed for the backplane's
  # service account, federated identity provider and role assignment.
  experiments = ["iam"]
}

module "server" {
  source = "../../../"

  meshstack = {
    owning_workspace_identifier = var.test_context.workspace
    tags                        = {}
  }
  hub = {
    git_ref   = var.test_context.hub_git_ref
    bbd_draft = true
  }

  bbd_display_name = "${var.test_context.run_id} STACKIT Server"

  stackit_project_id           = var.test_context.fixtures.stackit.project_id
  stackit_service_account_name = "${var.test_context.run_id}-srv"
}

output "version_ref" {
  value = module.server.building_block_definition.version_ref
}
