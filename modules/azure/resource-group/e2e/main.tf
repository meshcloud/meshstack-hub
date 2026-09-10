variable "test_context" {
  type = object({
    hub_git_ref = string
    workspace   = string
    run_id      = string

    fixtures = object({
      azure = object({
        subscription_uuid = string
        entra_tenant_id   = string
        mesh_tenant_id    = string
      })
    })
  })

  nullable = false
}

locals {
  azure_scope = "/subscriptions/${var.test_context.fixtures.azure.subscription_uuid}"

  # project_identifier is used in the resource group name: rg-<workspace>-<project>
  project_identifier = var.test_context.run_id
}

module "resource_group" {
  source = "../"

  meshstack = {
    owning_workspace_identifier = var.test_context.workspace
    tags                        = {}
  }

  hub = {
    git_ref   = var.test_context.hub_git_ref
    bbd_draft = true
  }

  bbd_display_name = "${var.test_context.run_id} Azure Resource Group"

  azure_tenant_id       = var.test_context.fixtures.azure.entra_tenant_id
  azure_subscription_id = var.test_context.fixtures.azure.subscription_uuid
  azure_scope           = local.azure_scope
  azure_location        = "westeurope"

  backplane_name = "${var.test_context.run_id}-rg-bp"
}

resource "meshstack_building_block" "this" {
  depends_on = [module.resource_group]

  wait_for_completion = true

  spec = {
    building_block_definition_version_ref = module.resource_group.building_block_definition.version_ref

    display_name = "${var.test_context.run_id}-resource-group"
    target_ref = {
      kind = "meshTenant"
      uuid = var.test_context.fixtures.azure.mesh_tenant_id
    }

    inputs = {
      workspace_identifier = { value = jsonencode(var.test_context.workspace) }
      project_identifier   = { value = jsonencode(local.project_identifier) }
    }
  }
}
