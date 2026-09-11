# Builds the definition from hub source, with an ephemeral backplane in the fixtures project.
variable "test_context" {
  type = object({
    workspace   = string
    run_id      = string
    hub_git_ref = string

    fixtures = object({
      gcp = object({
        project_id         = string
        billing_account_id = string
      })
    })
  })
  nullable = false
}

module "gcp_budget_alert" {
  source = "../../../"

  meshstack = {
    owning_workspace_identifier = var.test_context.workspace
    tags                        = {}
  }
  hub = {
    git_ref   = var.test_context.hub_git_ref
    bbd_draft = true
  }

  bbd_display_name = "${var.test_context.run_id} GCP Budget Alert"

  gcp_backplane_project_id = var.test_context.fixtures.gcp.project_id
  gcp_billing_account_id   = var.test_context.fixtures.gcp.billing_account_id

  # A service account is scoped to its project and GCP soft-deletes a workload identity pool for
  # ~30 days while refusing to reissue its id, so both names carry the run id: one run's leftovers
  # can then be swept without blocking the next run.
  backplane_service_account_id = "${var.test_context.run_id}-budget-sa"

  workload_identity = {
    pool_identifier = "${var.test_context.run_id}-budget-wif"
  }
}

output "version_ref" {
  value = module.gcp_budget_alert.building_block_definition.version_ref
}
