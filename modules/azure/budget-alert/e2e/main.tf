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
  azure_scope = "/subscriptions/${var.test_context.fixtures.azure.subscription_uuid}"

  budget_name = "${var.test_context.run_id}-budget"
}

module "budget_alert" {
  source = "../"

  meshstack = {
    owning_workspace_identifier = var.test_context.workspace
    tags                        = {}
  }

  hub = {
    git_ref   = var.test_context.hub_git_ref
    bbd_draft = true
  }

  bbd_display_name = "${var.test_context.run_id} Azure Budget Alert"

  azure_tenant_id       = var.test_context.fixtures.azure.entra_tenant_id
  azure_subscription_id = var.test_context.fixtures.azure.subscription_uuid
  azure_scope           = local.azure_scope

  backplane_name = "${var.test_context.run_id}-budget-bp"
}

resource "meshstack_building_block" "this" {
  depends_on = [module.budget_alert]

  wait_for_completion = true

  spec = {
    building_block_definition_version_ref = module.budget_alert.building_block_definition.version_ref

    display_name = "${var.test_context.run_id}-budget-alert"
    target_ref = {
      kind = "meshWorkspace"
      name = var.test_context.workspace
    }

    inputs = {
      # Two recipients, deliberately with the separating space the input's own example uses, so the
      # run exercises the comma splitting and trimming in local.contact_emails_list. A single
      # address would pass straight through and prove nothing about the parsing.
      contact_emails        = { value = jsonencode("e2e-test@example.com, e2e-test-second@example.com") }
      monthly_budget_amount = { value = jsonencode(1000) }
      budget_name           = { value = jsonencode(local.budget_name) }
    }
  }
}
