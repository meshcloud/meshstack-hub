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

  # key_vault_name must be globally unique, max 24 chars, alphanumeric + dashes only.
  # "kv-e2e-" (7 chars) + up to 12 chars from name_suffix = 19 chars max.
  key_vault_name = "kv-e2e-${substr(var.test_context.name_suffix, 0, 12)}"
}

module "key_vault" {
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
  azure_hub_scope       = local.azure_scope
  azure_location        = "westeurope"

  # Unique backplane name per test run so role definitions don't clash across concurrent/retried runs.
  backplane_name = "hub-e2e-key-vault-${var.test_context.name_suffix}"
}

resource "meshstack_building_block_v2" "this" {
  depends_on = [module.key_vault]

  wait_for_completion = true

  spec = {
    building_block_definition_version_ref = module.key_vault.building_block_definition.version_ref

    display_name = "smoke-test-key-vault-${var.test_context.name_suffix}"
    target_ref = {
      kind = "meshWorkspace"
      name = var.test_context.workspace
    }

    inputs = {
      key_vault_name                = { value_string = local.key_vault_name }
      location                      = { value_string = "westeurope" }
      key_vault_resource_group_name = { value_string = "rg-e2e-kv-${substr(var.test_context.name_suffix, 0, 12)}" }
    }
  }
}
