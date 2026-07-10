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

  # postgresql_server_name must match ^[a-z0-9-]{3,57}$ — the building block appends a 6-char suffix.
  # name_suffix is "YYYYMMDDhhmmss" (14 digits), so "pg-" + 14 digits = 17 chars total.
  postgresql_server_name = "pg-${var.test_context.name_suffix}"
}

module "postgresql" {
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
  backplane_name = "hub-e2e-pg-${var.test_context.name_suffix}"
}

resource "meshstack_building_block" "this" {
  # depend on the entire backplane to force correct resource ordering at the module boundary,
  # not just individual resources in the backplane
  depends_on = [module.postgresql]

  wait_for_completion = true

  spec = {
    building_block_definition_version_ref = module.postgresql.building_block_definition.version_ref

    display_name = "smoke-test-postgresql-${var.test_context.name_suffix}"
    target_ref = {
      kind = "meshWorkspace"
      name = var.test_context.workspace
    }

    inputs = {
      postgresql_server_name = { value = jsonencode(local.postgresql_server_name) }
    }
  }
}
