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

  # budget_name must be unique per test run to avoid conflicts on retried runs.
  # name_suffix is "YYYYMMDDhhmmss" (14 digits), prefix keeps the total short.
  budget_name = "e2e-${substr(var.test_context.name_suffix, 0, 12)}"
}

module "budget_alert" {
  source = "../"

  meshstack = {
    owning_workspace_identifier = var.test_context.workspace
    tags = {
      BBEnvironment = ["dev"]
    }
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

resource "meshstack_building_block_v2" "this" {
  depends_on = [module.budget_alert]

  wait_for_completion = true

  spec = {
    building_block_definition_version_ref = module.budget_alert.building_block_definition.version_ref

    display_name = "smoke-test-budget-alert-${var.test_context.name_suffix}"
    target_ref = {
      kind       = "meshWorkspace"
      identifier = var.test_context.workspace
    }

    inputs = {
      contact_emails        = { value_string = "e2e-test@example.com" }
      monthly_budget_amount = { value_int = 1000 }
      budget_name           = { value_string = local.budget_name }
    }
  }
}
