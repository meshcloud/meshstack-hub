variable "test_context" {
  type = object({
    workspace   = string
    run_id      = string
    hub_git_ref = string

    meshstack = optional(object({
      runner_ref = optional(object({
        kind = string
        uuid = string
      }))
    }))

    # Set to order an already-deployed BBD version; null to build the BBD from hub source.
    bbd_version_ref = optional(object({
      uuid = string
    }))

    # Only needed to provision the backplane. This building block is workspace-level, so its
    # target_ref needs no tenant id.
    fixtures = optional(object({
      aws = object({
        account_id = string
        region     = string

        # The account's shared OIDC provider for the meshStack runner issuer. AWS permits one per
        # issuer URL per account, so the harness owns it rather than each e2e run creating one.
        oidc_provider_arn = string
      })
    }))
  })
  nullable = false
}

locals {
  context_runner_ref = var.test_context.meshstack == null ? null : var.test_context.meshstack.runner_ref
}

variable "runner_switch" {
  type        = string
  default     = null
  description = "A step of the runner switch test in tests/aws_s3_bucket_runner_switch.tftest.hcl. `released_on_old_runner` releases version 1 with `old_runner`. `switched` creates a draft version 2 that uses `new_runner` and lists `old_runner` as trusted. Null runs the other tests, which use the runner in `test_context.meshstack.runner_ref`."

  validation {
    condition     = var.runner_switch == null || contains(["released_on_old_runner", "switched"], coalesce(var.runner_switch, "-"))
    error_message = "runner_switch must be null, released_on_old_runner or switched."
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
  description = "The runner of version 1 in the runner switch test."
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
  description = "The runner of version 2 in the runner switch test."
}

locals {
  runner_switch = var.runner_switch != null
  switched      = var.runner_switch == "switched"
}

data "meshstack_building_block_runner" "old" {
  count = local.runner_switch ? 1 : 0

  metadata = {
    owned_by_workspace = var.old_runner.owned_by_workspace
  }
  spec = {
    display_name = var.old_runner.display_name
  }
}

data "meshstack_building_block_runner" "new" {
  count = local.runner_switch ? 1 : 0

  metadata = {
    owned_by_workspace = var.new_runner.owned_by_workspace
  }
  spec = {
    display_name = var.new_runner.display_name
  }
}

# Credentials come from the environment: the CI role in the smoke-test account, or the developer's
# own session locally. allowed_account_ids turns a wrong session into an error instead of an IAM
# role in someone else's account.
provider "aws" {
  region              = var.test_context.fixtures != null ? var.test_context.fixtures.aws.region : null
  allowed_account_ids = var.test_context.fixtures != null ? [var.test_context.fixtures.aws.account_id] : null
}

module "aws_s3_bucket" {
  count  = var.test_context.bbd_version_ref == null ? 1 : 0
  source = "../"

  meshstack = {
    owning_workspace_identifier    = var.test_context.workspace
    tags                           = {}
    runner_ref                     = !local.runner_switch ? local.context_runner_ref : local.switched ? data.meshstack_building_block_runner.new[0].ref : data.meshstack_building_block_runner.old[0].ref
    additional_trusted_runner_refs = local.switched ? [data.meshstack_building_block_runner.old[0].ref] : []
  }
  hub = {
    git_ref   = var.test_context.hub_git_ref
    bbd_draft = var.runner_switch != "released_on_old_runner"
  }

  bbd_display_name = "${var.test_context.run_id} AWS S3 Bucket"

  aws_region = var.test_context.fixtures.aws.region

  backplane_name = "${var.test_context.run_id}-s3"
}

data "meshstack_building_block_definition" "this" {
  count = local.runner_switch ? 1 : 0

  metadata = {
    uuid = module.aws_s3_bucket[0].building_block_definition.uuid
  }
}

locals {
  hub_version_ref = local.runner_switch ? { uuid = data.meshstack_building_block_definition.this[0].version_latest_release.uuid } : { uuid = one(module.aws_s3_bucket[*].building_block_definition.version_ref.uuid) }
  version_ref     = var.test_context.bbd_version_ref != null ? var.test_context.bbd_version_ref : local.hub_version_ref

  bucket_name = local.switched ? "${var.test_context.run_id}-bucket-2" : "${var.test_context.run_id}-bucket"
}

resource "meshstack_building_block" "this" {
  # Nothing references the backplane role, so without this OpenTofu destroys it in parallel with the
  # delete run and the delete run can no longer authenticate against AWS.
  depends_on          = [module.aws_s3_bucket]
  wait_for_completion = true

  spec = {
    building_block_definition_version_ref = local.version_ref

    display_name = "${var.test_context.run_id}-s3-bucket"
    target_ref = {
      kind = "meshWorkspace"
      name = var.test_context.workspace
    }

    inputs = {
      bucket_name = { value = jsonencode(local.bucket_name) }
    }
  }
}
