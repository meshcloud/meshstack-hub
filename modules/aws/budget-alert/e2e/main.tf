variable "test_context" {
  # Untyped: each mode module re-types it strictly, so every field it needs stays required.
  type     = any
  nullable = false

  validation {
    condition     = can(var.test_context.workspace) && can(var.test_context.run_id)
    error_message = "test_context must provide workspace and run_id."
  }

  validation {
    condition     = can(var.test_context.fixtures.aws.mesh_tenant_id)
    error_message = "test_context must provide fixtures.aws.mesh_tenant_id — the budget is created in that tenant's AWS account."
  }

  validation {
    # `try` because `test_context` is untyped, so a hub run need not set `mode` at all.
    condition     = contains(["hub", "foundation"], try(var.test_context.mode, "hub"))
    error_message = "test_context.mode must be \"hub\" (the default) or \"foundation\"."
  }
}

variable "monthly_budget_amount" {
  type        = number
  default     = 1000000
  description = "Budget the test orders. Far above what the fixture account can spend in a month, so no threshold is crossed and no alert mail is sent."
}

locals {
  # Statically evaluated at `tofu init`, before any module is installed — so a foundation, which
  # already published the definition, never even resolves the hub build tree.
  mode = try(var.test_context.mode, "hub")

  budget_name = "${var.test_context.run_id}-budget"
}

module "definition" {
  source = "./modes/${local.mode}"

  test_context = var.test_context
}

resource "meshstack_building_block" "this" {
  # Orders teardown too: the delete run has to finish before the backplane's federated role is
  # destroyed, or it can no longer authenticate against AWS.
  depends_on = [module.definition]

  wait_for_completion = true
  spec = {
    building_block_definition_version_ref = { uuid = module.definition.version_ref.uuid }

    display_name = "${var.test_context.run_id} AWS Budget Alert"
    target_ref = {
      kind = "meshTenant"
      uuid = var.test_context.fixtures.aws.mesh_tenant_id
    }

    inputs = {
      budget_name                  = { value = jsonencode(local.budget_name) }
      monthly_budget_amount        = { value = jsonencode(var.monthly_budget_amount) }
      contact_emails               = { value = jsonencode("smoke-test@example.com") }
      actual_threshold_percent     = { value = jsonencode(90) }
      forecasted_threshold_percent = { value = jsonencode(110) }
    }
  }
}
