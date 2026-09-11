variable "test_context" {
  # Untyped: each mode module re-types it strictly, so every field it needs stays required.
  type     = any
  nullable = false

  validation {
    condition     = can(var.test_context.workspace) && can(var.test_context.run_id)
    error_message = "test_context must provide workspace and run_id."
  }

  validation {
    # Tenant-level building block, so both modes order it against a GCP tenant. The assertions also
    # read the billing account the budget lands under and the project hosting its notification
    # channel, so both modes have to supply those too.
    condition     = can(var.test_context.fixtures.gcp.mesh_tenant_id) && can(var.test_context.fixtures.gcp.billing_account_id) && can(var.test_context.fixtures.gcp.project_id)
    error_message = "test_context must provide fixtures.gcp with mesh_tenant_id, billing_account_id and project_id."
  }

  validation {
    # `try` because `test_context` is untyped, so a hub run need not set `mode` at all.
    condition     = contains(["hub", "foundation"], try(var.test_context.mode, "hub"))
    error_message = "test_context.mode must be \"hub\" (the default) or \"foundation\"."
  }
}

locals {
  # Statically evaluated at `tofu init`, before any module is installed — so a foundation, which has
  # already published the definition, never even resolves the hub build tree or the google provider.
  mode = try(var.test_context.mode, "hub")
}

module "definition" {
  source = "./modes/${local.mode}"

  test_context = var.test_context
}

locals {
  budget_name = "${var.test_context.run_id}-budget"

  # Deliberately far above what the fixtures project ever spends, so no threshold is crossed and no
  # alert mail is sent while the budget exists.
  budget_amount   = 100000
  budget_currency = "EUR"

  # A single non-default threshold, so the assertions prove the input reached the building block
  # rather than matching the definition's default.
  alert_thresholds_yaml = "- percent: 42\n  basis: ACTUAL\n"
}

resource "meshstack_building_block" "this" {
  # Nothing references the backplane's identity, so without this OpenTofu destroys it in parallel
  # with the delete run and the delete run can no longer authenticate against GCP.
  depends_on          = [module.definition]
  wait_for_completion = true

  spec = {
    building_block_definition_version_ref = { uuid = module.definition.version_ref.uuid }

    display_name = "${var.test_context.run_id}-budget-alert"
    target_ref = {
      kind = "meshTenant"
      uuid = var.test_context.fixtures.gcp.mesh_tenant_id
    }

    inputs = {
      budget_name           = { value = jsonencode(local.budget_name) }
      monthly_budget_amount = { value = jsonencode(local.budget_amount) }
      budget_currency       = { value = jsonencode(local.budget_currency) }
      contact_email         = { value = jsonencode("smoke-test-budget-alert@meshcloud.io") }
      # A CODE value reaches Terraform verbatim and alert_thresholds_yaml is a string variable, so
      # the raw YAML is sent. Encoding it twice would arrive as a quoted scalar.
      alert_thresholds_yaml = { value = jsonencode(local.alert_thresholds_yaml) }
    }
  }
}
