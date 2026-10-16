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
  experiments = ["iam"]
}

module "service_account" {
  source = "../../../../service-account"

  meshstack = {
    owning_workspace_identifier = var.test_context.workspace
    tags                        = {}
  }
  hub = {
    git_ref   = var.test_context.hub_git_ref
    bbd_draft = true
  }

  bbd_display_name = "${var.test_context.run_id} STACKIT Service Account"

  stackit_organization_id      = var.test_context.fixtures.stackit.organization_id
  stackit_project_id           = var.test_context.fixtures.stackit.project_id
  stackit_service_account_name = "${var.test_context.run_id}-sabp"
}

module "service_account_federation" {
  source = "../../../"

  meshstack = {
    owning_workspace_identifier = var.test_context.workspace
    tags                        = {}
  }
  hub = {
    git_ref   = var.test_context.hub_git_ref
    bbd_draft = true
  }

  bbd_display_name = "${var.test_context.run_id} STACKIT Service Account Federation"

  stackit_organization_id      = var.test_context.fixtures.stackit.organization_id
  stackit_project_id           = var.test_context.fixtures.stackit.project_id
  stackit_service_account_name = "${var.test_context.run_id}-fdbp"
}

output "service_account_version_ref" {
  value = module.service_account.building_block_definition.version_ref
}

output "version_ref" {
  value = module.service_account_federation.building_block_definition.version_ref
}

output "definition_uuid" {
  value = module.service_account_federation.building_block_definition.uuid
}
