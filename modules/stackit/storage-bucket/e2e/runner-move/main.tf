provider "stackit" {
  experiments = ["iam"]
}

data "meshstack_building_block_runner" "old" {
  metadata = {
    owned_by_workspace = var.old_runner.owned_by_workspace
  }
  spec = {
    display_name = var.old_runner.display_name
  }
}

data "meshstack_building_block_runner" "new" {
  metadata = {
    owned_by_workspace = var.new_runner.owned_by_workspace
  }
  spec = {
    display_name = var.new_runner.display_name
  }
}

locals {
  moved = var.scenario == "moved"
}

module "stackit_storage_bucket" {
  source = "../../"

  meshstack = {
    owning_workspace_identifier = var.test_context.workspace
    tags                        = {}
    runner_ref                  = local.moved ? data.meshstack_building_block_runner.new.ref : data.meshstack_building_block_runner.old.ref
    trusted_runner_refs         = local.moved ? [data.meshstack_building_block_runner.old.ref] : []
  }

  hub = {
    git_ref   = var.test_context.hub_git_ref
    bbd_draft = local.moved
  }

  bbd_display_name = "${var.test_context.run_id} STACKIT Storage Bucket runner move"

  stackit_project_id           = var.test_context.fixtures.stackit.project_id
  stackit_service_account_name = "${var.test_context.run_id}-sbm"
}

data "meshstack_building_block_definition" "this" {
  metadata = {
    uuid = module.stackit_storage_bucket.building_block_definition.uuid
  }
}

resource "meshstack_building_block" "on_old_runner" {
  depends_on          = [module.stackit_storage_bucket]
  wait_for_completion = true

  spec = {
    building_block_definition_version_ref = {
      uuid = data.meshstack_building_block_definition.this.version_latest_release.uuid
    }

    display_name = "${var.test_context.run_id}-bucket-old-runner"
    target_ref = {
      kind = "meshWorkspace"
      name = var.test_context.workspace
    }

    inputs = {
      bucket_name = { value = jsonencode(local.moved ? "${var.test_context.run_id}-old-2" : "${var.test_context.run_id}-old-1") }
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
      uuid = module.stackit_storage_bucket.building_block_definition.version_ref.uuid
    }

    display_name = "${var.test_context.run_id}-bucket-new-runner"
    target_ref = {
      kind = "meshWorkspace"
      name = var.test_context.workspace
    }

    inputs = {
      bucket_name = { value = jsonencode("${var.test_context.run_id}-new") }
    }
  }
}
