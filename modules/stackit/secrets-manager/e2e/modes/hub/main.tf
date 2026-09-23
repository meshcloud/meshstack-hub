variable "test_context" {
  type = object({
    hub_git_ref = string
    workspace   = string
    run_id      = string

    fixtures = object({
      stackit = object({
        organization_id = string
        project_id      = string
      })
    })
  })
  nullable = false
}

provider "stackit" {
  # Credentials come from the environment, WIF in CI.
  experiments = ["iam"]
}

module "secrets_manager" {
  source = "../../../"

  meshstack = {
    owning_workspace_identifier = var.test_context.workspace
    tags                        = {}
  }
  hub = {
    git_ref   = var.test_context.hub_git_ref
    bbd_draft = true
  }

  bbd_display_name = "${var.test_context.run_id} STACKIT Secrets Manager"

  stackit_organization_id      = var.test_context.fixtures.stackit.organization_id
  stackit_project_id           = var.test_context.fixtures.stackit.project_id
  stackit_service_account_name = "${var.test_context.run_id}-sm"
}

output "version_ref" {
  value = module.secrets_manager.building_block_definition.version_ref
}
