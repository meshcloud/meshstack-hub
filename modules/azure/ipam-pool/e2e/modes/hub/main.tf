variable "test_context" {
  type = object({
    hub_git_ref = string
    workspace   = string
    run_id      = string

    fixtures = object({
      azure = object({
        subscription_uuid = string
        entra_tenant_id   = string
      })
    })
  })
  nullable = false
}

provider "azurerm" {
  # Credentials come from the environment, WIF in CI. The backplane identity lives in the fixture
  # subscription, which also hosts the tenant the building block is ordered for.
  subscription_id = var.test_context.fixtures.azure.subscription_uuid
  tenant_id       = var.test_context.fixtures.azure.entra_tenant_id

  features {}
}

module "ipam_pool" {
  source = "../../../"

  meshstack = {
    owning_workspace_identifier = var.test_context.workspace
    tags                        = {}
  }
  hub = {
    git_ref   = var.test_context.hub_git_ref
    bbd_draft = true
  }

  bbd_display_name = "${var.test_context.run_id} Azure IPAM Pool"

  azure_tenant_id                 = var.test_context.fixtures.azure.entra_tenant_id
  azure_scope                     = "/subscriptions/${var.test_context.fixtures.azure.subscription_uuid}"
  azure_backplane_subscription_id = var.test_context.fixtures.azure.subscription_uuid
  azure_resource_group_name       = "${var.test_context.run_id}-ipam"
  backplane_name                  = "${var.test_context.run_id}-ipam-bp"
}

output "version_ref" {
  value = module.ipam_pool.building_block_definition.version_ref
}
