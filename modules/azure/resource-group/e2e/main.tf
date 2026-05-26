variable "test_context" {
  type = object({
    hub_git_ref = string
    workspace   = string
    name_suffix = string

    fixtures = object({
      azure = object({
        subscription_uuid = string
        entra_tenant_id   = string
      })
    })
  })

  nullable = false
}

locals {
  azure_scope = "/subscriptions/${var.test_context.fixtures.azure.subscription_uuid}"

  # project_identifier is used in the resource group name: rg-<workspace>-<project>
  # Keep it short and valid: only lowercase alphanumeric and dashes.
  project_identifier = "e2e-${substr(var.test_context.name_suffix, 0, 10)}"
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

  azure_tenant_id       = var.test_context.fixtures.azure.entra_tenant_id
  azure_subscription_id = var.test_context.fixtures.azure.subscription_uuid
  azure_scope           = local.azure_scope
  azure_location        = "westeurope"

  # Unique backplane name per test run so role definitions don't clash across concurrent/retried runs.
  backplane_name = "hub-e2e-rg-${var.test_context.name_suffix}"
}

resource "meshstack_building_block_v2" "this" {
  depends_on = [module.resource_group]

  wait_for_completion = true

  spec = {
    building_block_definition_version_ref = module.resource_group.building_block_definition.version_ref

    display_name = "smoke-test-resource-group-${var.test_context.name_suffix}"
    target_ref = {
      kind = "meshWorkspace"
      name = var.test_context.workspace
    }

    inputs = {
      workspace_identifier = { value_string = var.test_context.workspace }
      project_identifier   = { value_string = local.project_identifier }
    }
  }
}
