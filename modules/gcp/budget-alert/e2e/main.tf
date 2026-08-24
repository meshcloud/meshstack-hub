variable "test_context" {
  type = object({
    workspace   = string
    name_suffix = string
    hub_git_ref = string

    # Set to order an already-deployed BBD version; null to build the BBD from hub source.
    bbd_version_ref = optional(object({
      uuid = string
    }))

    # This building block is tenant-level, so the tenant id is needed in both modes.
    fixtures = optional(object({
      gcp = object({
        project_id         = string
        mesh_tenant_id     = string
        billing_account_id = string
      })
    }))
  })
  nullable = false
}

provider "google" {
  # Credentials come from the environment: Application Default Credentials locally, WIF in CI.
  project = var.test_context.fixtures.gcp.project_id
}

module "gcp_budget_alert" {
  count  = var.test_context.bbd_version_ref == null ? 1 : 0
  source = "../"

  meshstack = {
    owning_workspace_identifier = var.test_context.workspace
    tags                        = {}
  }
  hub = {
    git_ref   = var.test_context.hub_git_ref
    bbd_draft = true
  }

  gcp_backplane_project_id = var.test_context.fixtures.gcp.project_id
  gcp_billing_account_id   = var.test_context.fixtures.gcp.billing_account_id

  # GCP soft-deletes workload identity pools for ~30 days and refuses to reissue their ids in that
  # window, so a fixed pool id makes every rerun fail.
  workload_identity = {
    pool_identifier = "hub-e2e-budget-${var.test_context.name_suffix}"
  }
}

locals {
  version_ref = var.test_context.bbd_version_ref != null ? var.test_context.bbd_version_ref : module.gcp_budget_alert[0].building_block_definition.version_ref

  budget_name = "smoke-test-gcp-budget-${var.test_context.name_suffix}"

  # Deliberately far above what the fixtures project ever spends, so no threshold is crossed and no
  # alert mail is sent while the budget exists.
  budget_amount   = 100000
  budget_currency = "EUR"

  # A single non-default threshold, so the assertions prove the input reached the building block
  # rather than matching the definition's default.
  alert_thresholds_yaml = "- percent: 42\n  basis: ACTUAL\n"
}

resource "meshstack_building_block" "this" {
  # Nothing references the backplane's service account, so without this OpenTofu destroys it in
  # parallel with the delete run and the delete run can no longer authenticate against GCP.
  depends_on          = [module.gcp_budget_alert]
  wait_for_completion = true

  spec = {
    building_block_definition_version_ref = { uuid = local.version_ref.uuid }

    display_name = "smoke-test-gcp-budget-alert-${var.test_context.name_suffix}"
    target_ref = {
      kind = "meshTenant"
      uuid = var.test_context.fixtures.gcp.mesh_tenant_id
    }

    inputs = {
      budget_name           = { value = jsonencode(local.budget_name) }
      monthly_budget_amount = { value = jsonencode(local.budget_amount) }
      budget_currency       = { value = jsonencode(local.budget_currency) }
      contact_email         = { value = jsonencode("smoke-test-budget-alert@meshcloud.io") }
      # CODE inputs are parsed by the runner, so the value is encoded twice.
      alert_thresholds_yaml = { value = jsonencode(jsonencode(local.alert_thresholds_yaml)) }
    }
  }
}
