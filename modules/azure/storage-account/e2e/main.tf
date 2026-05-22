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
  # Derive the scope from the subscription ID — role definitions are scoped to the subscription.
  azure_scope = "/subscriptions/${var.test_context.fixtures.azure.subscription_uuid}"

  # storage_account_name must match ^[a-z0-9]{3,19}$ — building block appends a 5-char random suffix.
  # name_suffix is "YYYYMMDDhhmmss" (14 digits), so "st" + first 12 digits = 14 chars total.
  storage_account_name_prefix = "st${substr(var.test_context.name_suffix, 0, 12)}"
}

module "storage_account" {
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

  # Unique backplane name per test run so role definitions don't clash across concurrent/retried runs.
  backplane_name = "hub-e2e-stg-${var.test_context.name_suffix}"
}

resource "meshstack_building_block_v2" "this" {
  # depend on the entire backplane to force correct resource ordering at the module boundary,not just individual resources in the backplane
  depends_on = [module.storage_account]

  wait_for_completion = true

  spec = {
    building_block_definition_version_ref = module.storage_account.building_block_definition.version_ref

    display_name = "smoke-test-storage-account-${var.test_context.name_suffix}"
    target_ref = {
      kind = "meshWorkspace"
      name = var.test_context.workspace
    }

    inputs = {
      storage_account_name = { value_string = local.storage_account_name_prefix }
    }
  }
}
