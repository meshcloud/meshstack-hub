variable "test_context" {
  type     = any
  nullable = false

  validation {
    condition     = can(var.test_context.workspace) && can(var.test_context.run_id)
    error_message = "test_context must provide workspace and run_id."
  }

  validation {
    condition     = can(var.test_context.fixtures.azure.mesh_tenant_id)
    error_message = "test_context must provide fixtures.azure.mesh_tenant_id, the tenant to order the building block for."
  }

  validation {
    # `try` because `test_context` is untyped, so a hub run need not set `mode` at all.
    condition     = contains(["hub", "foundation"], try(var.test_context.mode, "hub"))
    error_message = "test_context.mode must be \"hub\" (the default) or \"foundation\"."
  }
}

locals {
  # `try` because `test_context` is untyped, so a hub run need not set `mode` at all.
  mode = try(var.test_context.mode, "hub")
}

module "definition" {
  source = "./modes/${local.mode}"

  test_context = var.test_context
}

resource "meshstack_building_block" "this" {
  # Also orders teardown: the delete run must finish before the backplane's WIF trust is destroyed.
  depends_on = [module.definition]

  wait_for_completion = true

  spec = {
    building_block_definition_version_ref = { uuid = module.definition.version_ref.uuid }

    display_name = "${var.test_context.run_id} Azure Key Vault"
    # `subscription_id` is a PLATFORM_TENANT_ID input, which meshStack resolves from this tenant.
    target_ref = {
      kind = "meshTenant"
      uuid = var.test_context.fixtures.azure.mesh_tenant_id
    }

    inputs = {
      # Purge protection keeps a deleted vault's name reserved for 7 days, which the per-run id
      # sidesteps.
      key_vault_name                = { value = jsonencode(var.test_context.run_id) }
      key_vault_resource_group_name = { value = jsonencode("${var.test_context.run_id}-kv") }
      public_network_access_enabled = { value = jsonencode(false) }
      private_endpoint_enabled      = { value = jsonencode(false) }
    }
  }
}
