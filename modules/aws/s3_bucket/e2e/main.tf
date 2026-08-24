variable "test_context" {
  type = object({
    workspace   = string
    name_suffix = string
    hub_git_ref = string

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

        # False in the smoke-test account: the meshStack issuer's OIDC provider is a long-lived
        # fixture there, because AWS permits one per issuer URL per account and several AWS e2e
        # cases run in parallel.
        create_oidc_provider = bool
      })
    }))
  })
  nullable = false
}

# Credentials come from the environment: the CI role in the smoke-test account, or the developer's
# own session locally. allowed_account_ids turns a wrong session into an error instead of an IAM
# role in someone else's account.
provider "aws" {
  region              = var.test_context.fixtures != null ? var.test_context.fixtures.aws.region : null
  allowed_account_ids = var.test_context.fixtures != null ? [var.test_context.fixtures.aws.account_id] : null
}

data "meshstack_integrations" "this" {}

locals {
  replicator = data.meshstack_integrations.this.workload_identity_federation.replicator

  # The integration composes subjects as `system:serviceaccount:<prefix>:workspace.…`, so strip the
  # replicator's own subject down to the namespace part it shares with every building block run.
  subject_namespace_prefix = trimsuffix(trimprefix(local.replicator.subject, "system:serviceaccount:"), ":replicator")
}

module "aws_s3_bucket" {
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

  aws_region           = var.test_context.fixtures.aws.region
  create_oidc_provider = var.test_context.fixtures.aws.create_oidc_provider

  workload_identity = {
    issuer                   = local.replicator.issuer
    audience                 = local.replicator.aws.audience
    subject_namespace_prefix = local.subject_namespace_prefix
  }
}

locals {
  version_ref = var.test_context.bbd_version_ref != null ? var.test_context.bbd_version_ref : module.aws_s3_bucket[0].building_block_definition.version_ref

  # S3 bucket names are globally unique across all of AWS, so the suffix is what keeps concurrent
  # and repeated runs from colliding.
  bucket_name = "smoke-test-aws-bucket-${var.test_context.name_suffix}"
}

resource "meshstack_building_block" "this" {
  # Nothing references the backplane role, so without this OpenTofu destroys it in parallel with the
  # delete run and the delete run can no longer authenticate against AWS.
  depends_on          = [module.aws_s3_bucket]
  wait_for_completion = true

  spec = {
    building_block_definition_version_ref = { uuid = local.version_ref.uuid }

    display_name = "smoke-test-aws-s3-bucket-${var.test_context.name_suffix}"
    target_ref = {
      kind = "meshWorkspace"
      name = var.test_context.workspace
    }

    inputs = {
      bucket_name = { value = jsonencode(local.bucket_name) }
    }
  }
}
