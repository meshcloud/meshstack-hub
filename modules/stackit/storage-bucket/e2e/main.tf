variable "test_context" {
  type = object({
    workspace   = string
    run_id      = string
    hub_git_ref = string

    # Mode discriminator: set in foundation mode to order an already-deployed BBD version;
    # null in build-from-source mode, which builds the BBD from hub source.
    bbd_version_ref = optional(object({
      uuid = string
    }))

    # Cloud resource IDs. Needed in build-from-source mode (to provision the backplane) and, for
    # tenant-level building blocks, also in foundation mode (the target_ref tenant id).
    fixtures = optional(object({
      stackit = object({
        project_id     = string
        mesh_tenant_id = string
      })
    }))
  })
  nullable = false
}

variable "runner_move" {
  type        = string
  default     = null
  description = "Null runs the plain test. `released_on_old_runner` releases the definition on `old_runner`. `moved` moves it to `new_runner` and lists `old_runner` as trusted. See tests/stackit_storage_bucket_runner_move.tftest.hcl."

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
  description = "The runner the definition starts on in the runner move test. It must offer the Azure token."
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
  description = "The runner the definition moves to in the runner move test. It must offer the Azure token and have another issuer than `old_runner`."
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

provider "stackit" {
  # Credentials are picked up from the environment: STACKIT_SERVICE_ACCOUNT_KEY_PATH for local
  # development (see meshstack-smoke-test/setup-env.sh), WIF in CI. Do not set service_account_key
  # here — an explicit null argument overrides the env-based credential discovery.
  experiments = ["iam"]
}

module "stackit_storage_bucket" {
  count  = var.test_context.bbd_version_ref == null ? 1 : 0
  source = "../"
  meshstack = {
    owning_workspace_identifier = var.test_context.workspace
    tags                        = {}
    runner_ref                  = !local.runner_move ? null : local.moved ? data.meshstack_building_block_runner.new[0].ref : data.meshstack_building_block_runner.old[0].ref
    trusted_runner_refs         = local.moved ? [data.meshstack_building_block_runner.old[0].ref] : []
  }
  hub = {
    git_ref   = var.test_context.hub_git_ref
    bbd_draft = var.runner_move != "released_on_old_runner"
  }

  bbd_display_name = "${var.test_context.run_id} STACKIT Storage Bucket"

  stackit_project_id           = var.test_context.fixtures.stackit.project_id
  stackit_service_account_name = "${var.test_context.run_id}-sb"
}

data "meshstack_building_block_definition" "this" {
  count = local.runner_move ? 1 : 0

  metadata = {
    uuid = module.stackit_storage_bucket[0].building_block_definition.uuid
  }
}

locals {
  hub_version_ref = local.runner_move ? { uuid = data.meshstack_building_block_definition.this[0].version_latest_release.uuid } : { uuid = one(module.stackit_storage_bucket[*].building_block_definition.version_ref.uuid) }
  version_ref     = var.test_context.bbd_version_ref != null ? var.test_context.bbd_version_ref : local.hub_version_ref
}

resource "meshstack_building_block" "this" {
  # Explicit dependency ensures the building block (and its delete run) is fully destroyed before
  # any backplane resources are torn down. Without this, OpenTofu destroys the WIF federated
  # identity providers in parallel with the delete run, causing 401s from the STACKIT provider.
  depends_on          = [module.stackit_storage_bucket]
  wait_for_completion = true
  spec = {
    building_block_definition_version_ref = local.version_ref

    display_name = "${var.test_context.run_id}-storage-bucket"
    target_ref = {
      kind = "meshWorkspace"
      name = var.test_context.workspace
    }

    inputs = {
      bucket_name = { value = jsonencode(local.moved ? "${var.test_context.run_id}-bucket-2" : "${var.test_context.run_id}-bucket") }
    }
  }
}

resource "meshstack_building_block" "on_new_runner" {
  lifecycle {
    enabled = local.moved
  }

  depends_on          = [module.stackit_storage_bucket]
  wait_for_completion = true

  spec = {
    building_block_definition_version_ref = {
      uuid = one(module.stackit_storage_bucket[*].building_block_definition.version_ref.uuid)
    }

    display_name = "${var.test_context.run_id}-storage-bucket-new"
    target_ref = {
      kind = "meshWorkspace"
      name = var.test_context.workspace
    }

    inputs = {
      bucket_name = { value = jsonencode("${var.test_context.run_id}-bucket-new") }
    }
  }
}
