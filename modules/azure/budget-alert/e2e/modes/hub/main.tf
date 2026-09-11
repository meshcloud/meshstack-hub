# Builds the budget-alert definition from hub source, with an ephemeral backplane in the fixture
# subscription.
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
}

module "budget_alert" {
  source = "../../../"

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
  backplane_name = "hub-e2e-budget-${var.test_context.name_suffix}"
}

output "version_ref" {
  value = module.budget_alert.building_block_definition.version_ref
}
