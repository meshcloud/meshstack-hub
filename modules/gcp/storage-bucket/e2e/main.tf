variable "test_context" {
  type = object({
    workspace   = string
    run_id      = string
    hub_git_ref = string

    # Set to order an already-deployed BBD version; null to build the BBD from hub source.
    bbd_version_ref = optional(object({
      uuid = string
    }))

    # Only needed to provision the backplane. This building block is workspace-level, so its
    # target_ref needs no tenant id.
    fixtures = optional(object({
      gcp = object({
        project_id = string
      })
    }))
  })
  nullable = false
}

provider "google" {
  # Credentials come from the environment: Application Default Credentials locally, WIF in CI.
  project = var.test_context.fixtures != null ? var.test_context.fixtures.gcp.project_id : null
}

module "gcp_storage_bucket" {
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

  bbd_display_name = "${var.test_context.run_id} GCP Storage Bucket"

  gcp_project_id = var.test_context.fixtures.gcp.project_id

  backplane_service_account_id = "${var.test_context.run_id}-storage-sa"

  workload_identity = {
    pool_identifier = "${var.test_context.run_id}-wif"
  }
}

locals {
  version_ref = var.test_context.bbd_version_ref != null ? var.test_context.bbd_version_ref : module.gcp_storage_bucket[0].building_block_definition.version_ref

  bucket_name = "${var.test_context.run_id}-bucket"
  location    = "europe-west1"
}

resource "meshstack_building_block" "this" {
  # Nothing references the workload identity pool, so without this OpenTofu destroys it in parallel
  # with the delete run and the delete run can no longer authenticate against GCP.
  depends_on          = [module.gcp_storage_bucket]
  wait_for_completion = true

  spec = {
    building_block_definition_version_ref = { uuid = local.version_ref.uuid }

    display_name = "${var.test_context.run_id}-storage-bucket"
    target_ref = {
      kind = "meshWorkspace"
      name = var.test_context.workspace
    }

    inputs = {
      bucket_name = { value = jsonencode(local.bucket_name) }
      location    = { value = jsonencode(local.location) }
      # CODE inputs are parsed as HCL by the runner, so the value is encoded twice.
      labels = { value = jsonencode(jsonencode(["env:hub-e2e", "team:smoke-test"])) }
    }
  }
}
