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

locals {
  # Derive the scope from the subscription ID — role definitions are scoped to the subscription.
  azure_scope = "/subscriptions/${var.test_context.fixtures.azure.subscription_uuid}"

  # storage_account_name must match ^[a-z0-9]{3,19}$ — building block appends a 5-char random suffix,
  # so the final name is the 15-character run id plus 5, inside Azure's 24-character limit.
  storage_account_name_prefix = var.test_context.run_id
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

  bbd_display_name = "${var.test_context.run_id} Azure Storage Account"

  azure_tenant_id       = var.test_context.fixtures.azure.entra_tenant_id
  azure_subscription_id = var.test_context.fixtures.azure.subscription_uuid
  azure_scope           = local.azure_scope

  backplane_name = "${var.test_context.run_id}-stg-bp"
}

resource "meshstack_building_block" "this" {
  # depend on the entire backplane to force correct resource ordering at the module boundary,not just individual resources in the backplane
  depends_on = [module.storage_account]

  wait_for_completion = true

  spec = {
    building_block_definition_version_ref = module.storage_account.building_block_definition.version_ref

    display_name = "${var.test_context.run_id}-storage-account"
    target_ref = {
      kind = "meshWorkspace"
      name = var.test_context.workspace
    }

    inputs = {
      storage_account_name = { value = jsonencode(local.storage_account_name_prefix) }
    }
  }
}
