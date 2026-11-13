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

variable "runner_move" {
  type        = string
  default     = null
  description = "Null runs the plain test. `released_on_old_runner` releases the definition on `old_runner`. `moved` moves it to `new_runner` and lists `old_runner` as trusted. See tests/gcp_storage_bucket_runner_move.tftest.hcl."

  validation {
    condition     = var.runner_move == null || contains(["released_on_old_runner", "moved"], coalesce(var.runner_move, "-"))
    error_message = "runner_move must be null, released_on_old_runner or moved."
  }
}

variable "old_runner" {
  type = object({
    owned_by_workspace = string
    display_name       = string
  })
  default = {
    owned_by_workspace = "admin-customer"
    display_name       = "meshcloud-hosted Runner (deprecated)"
  }
  description = "The runner the definition starts on in the runner move test. It must offer the GCP token."
}

variable "new_runner" {
  type = object({
    owned_by_workspace = string
    display_name       = string
  })
  default = {
    owned_by_workspace = "admin-customer"
    display_name       = "meshcloud-hosted Runner (meshStack identity)"
  }
  description = "The runner the definition moves to in the runner move test. It must offer the GCP token and have another issuer than `old_runner`."
}

locals {
  runner_move = var.runner_move != null
  moved       = var.runner_move == "moved"
}

data "meshstack_building_block_runner" "old" {
  count = local.runner_move ? 1 : 0

  metadata = {
    owned_by_workspace = var.old_runner.owned_by_workspace
  }
  spec = {
    display_name = var.old_runner.display_name
  }
}

data "meshstack_building_block_runner" "new" {
  count = local.runner_move ? 1 : 0

  metadata = {
    owned_by_workspace = var.new_runner.owned_by_workspace
  }
  spec = {
    display_name = var.new_runner.display_name
  }
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
    runner_ref                  = !local.runner_move ? null : local.moved ? data.meshstack_building_block_runner.new[0].ref : data.meshstack_building_block_runner.old[0].ref
    trusted_runner_refs         = local.moved ? [data.meshstack_building_block_runner.old[0].ref] : []
    original_runner_ref         = local.moved ? data.meshstack_building_block_runner.old[0].ref : null
  }
  hub = {
    git_ref   = var.test_context.hub_git_ref
    bbd_draft = var.runner_move != "released_on_old_runner"
  }

  bbd_display_name = "${var.test_context.run_id} GCP Storage Bucket"

  gcp_project_id = var.test_context.fixtures.gcp.project_id

  backplane_service_account_id = "${var.test_context.run_id}-storage-sa"

  workload_identity = {
    pool_identifier = "${var.test_context.run_id}-wif"
  }
}

data "meshstack_building_block_definition" "this" {
  count = local.runner_move ? 1 : 0

  metadata = {
    uuid = module.gcp_storage_bucket[0].building_block_definition.uuid
  }
}

locals {
  hub_version_ref = local.runner_move ? { uuid = data.meshstack_building_block_definition.this[0].version_latest_release.uuid } : { uuid = one(module.gcp_storage_bucket[*].building_block_definition.version_ref.uuid) }
  version_ref     = var.test_context.bbd_version_ref != null ? var.test_context.bbd_version_ref : local.hub_version_ref

  bucket_name = "${var.test_context.run_id}-bucket"
  location    = "europe-west1"
}

resource "meshstack_building_block" "this" {
  # Nothing references the workload identity pool, so without this OpenTofu destroys it in parallel
  # with the delete run and the delete run can no longer authenticate against GCP.
  depends_on          = [module.gcp_storage_bucket]
  wait_for_completion = true

  spec = {
    building_block_definition_version_ref = local.version_ref

    display_name = "${var.test_context.run_id}-storage-bucket"
    target_ref = {
      kind = "meshWorkspace"
      name = var.test_context.workspace
    }

    inputs = {
      bucket_name = { value = jsonencode(local.bucket_name) }
      location    = { value = jsonencode(local.location) }
      # CODE inputs are parsed as HCL by the runner, so the value is encoded twice.
      labels = { value = jsonencode(jsonencode(local.moved ? ["env:hub-e2e", "team:smoke-test", "runner:moved"] : ["env:hub-e2e", "team:smoke-test"])) }
    }
  }
}
