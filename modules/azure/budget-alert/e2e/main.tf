variable "test_context" {
  # Untyped: each mode module re-types it strictly, so every field it needs stays required.
  type     = any
  nullable = false

  validation {
    condition     = can(var.test_context.workspace) && can(var.test_context.name_suffix)
    error_message = "test_context must provide workspace and name_suffix."
  }

  validation {
    # `try` because `test_context` is untyped, so a hub run need not set `mode` at all.
    condition     = contains(["hub", "foundation"], try(var.test_context.mode, "hub"))
    error_message = "test_context.mode must be \"hub\" (the default) or \"foundation\"."
  }
}

locals {
  # Statically evaluated at `tofu init`, before any module is installed — so a foundation, which
  # already published the definition, never even resolves the hub build tree.
  mode = try(var.test_context.mode, "hub")

  # budget_name must be unique per test run to avoid conflicts on retried runs.
  # name_suffix is "YYYYMMDDhhmmss" (14 digits), prefix keeps the total short.
  budget_name = "e2e-${substr(var.test_context.name_suffix, 0, 12)}"
}

module "definition" {
  source = "./modes/${local.mode}"

  test_context = var.test_context
}

resource "meshstack_building_block" "this" {
  depends_on = [module.definition]

  wait_for_completion = true

  spec = {
    building_block_definition_version_ref = { uuid = module.definition.version_ref.uuid }

    display_name = "smoke-test-budget-alert-${var.test_context.name_suffix}"
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
