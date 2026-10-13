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

module "key_vault" {
  source = "../../../"

  meshstack = {
    owning_workspace_identifier = var.test_context.workspace
    tags                        = {}
  }
  hub = {
    git_ref   = var.test_context.hub_git_ref
    bbd_draft = true
  }

  bbd_display_name = "${var.test_context.run_id} Azure Key Vault"
  # Exercises the schedule a foundation sets to revert drift; the definition is rejected if meshStack
  # does not accept it.
  bbd_schedule = {
    mode               = "DRIFT_RECONCILIATION"
    frequency          = "DAILY"
    automatic_approval = true
  }

  azure_tenant_id = var.test_context.fixtures.azure.entra_tenant_id
  azure_scope     = "/subscriptions/${var.test_context.fixtures.azure.subscription_uuid}"
  backplane_name  = "${var.test_context.run_id}-kv-bp"
}

output "version_ref" {
  value = module.key_vault.building_block_definition.version_ref
}
