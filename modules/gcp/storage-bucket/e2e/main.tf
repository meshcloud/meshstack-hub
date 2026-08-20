variable "test_context" {
  type = object({
    workspace   = string
    name_suffix = string
    hub_git_ref = string

    # Mode discriminator: set in foundation mode to order an already-deployed BBD version;
    # null in build-from-source mode, which builds the BBD from hub source.
    bbd_version_ref = optional(object({
      uuid = string
    }))

    # Cloud resource IDs. Needed in build-from-source mode to provision the backplane. This is a
    # workspace-level building block, so foundation mode does not need them for target_ref.
    fixtures = optional(object({
      gcp = object({
        project_id = string
      })
    }))
  })
  nullable = false
}

provider "google" {
  # Credentials are picked up from the environment: Application Default Credentials for local
  # development (gcloud auth application-default login), WIF in CI.
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

  gcp_project_id = var.test_context.fixtures.gcp.project_id

  # GCP soft-deletes workload identity pools (and their providers) for ~30 days and refuses to
  # hand the same identifier out again during that window, so a fixed pool id would make every
  # rerun fail. Derive a fresh identifier per test run instead. Pool ids allow 4-32 chars of
  # [a-z0-9-] and must not start with "gcp-"; "hub-e2e-" + the 14-digit timestamp fits in 22.
  workload_identity = {
    pool_identifier = "hub-e2e-${var.test_context.name_suffix}"
  }
}

locals {
  version_ref = var.test_context.bbd_version_ref != null ? var.test_context.bbd_version_ref : module.gcp_storage_bucket[0].building_block_definition.version_ref

  # GCS bucket names are globally unique across all of Google Cloud, so the per-run timestamp
  # suffix is what keeps concurrent and repeated runs from colliding.
  bucket_name = "smoke-test-gcp-bucket-${var.test_context.name_suffix}"
  location    = "europe-west1"
}

resource "meshstack_building_block" "this" {
  # Explicit dependency ensures the building block (and its delete run) is fully destroyed before
  # any backplane resources are torn down. Without this, OpenTofu destroys the workload identity
  # pool in parallel with the delete run, which then fails to authenticate against GCP.
  depends_on          = [module.gcp_storage_bucket]
  wait_for_completion = true

  spec = {
    building_block_definition_version_ref = { uuid = local.version_ref.uuid }

    display_name = "smoke-test-gcp-storage-bucket-${var.test_context.name_suffix}"
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
