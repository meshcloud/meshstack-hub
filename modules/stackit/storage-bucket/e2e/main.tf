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
  }
  hub = {
    git_ref   = var.test_context.hub_git_ref
    bbd_draft = true
  }

  bbd_display_name = "${var.test_context.run_id} STACKIT Storage Bucket"

  stackit_project_id           = var.test_context.fixtures.stackit.project_id
  stackit_service_account_name = "${var.test_context.run_id}-sb"
}

locals {
  version_ref = var.test_context.bbd_version_ref != null ? var.test_context.bbd_version_ref : module.stackit_storage_bucket[0].building_block_definition.version_ref
}

resource "meshstack_building_block" "this" {
  # Explicit dependency ensures the building block (and its delete run) is fully destroyed before
  # any backplane resources are torn down. Without this, OpenTofu destroys the WIF federated
  # identity providers in parallel with the delete run, causing 401s from the STACKIT provider.
  depends_on          = [module.stackit_storage_bucket]
  wait_for_completion = true
  spec = {
    building_block_definition_version_ref = { uuid = local.version_ref.uuid }

    display_name = "${var.test_context.run_id}-storage-bucket"
    target_ref = {
      kind = "meshWorkspace"
      name = var.test_context.workspace
    }

    inputs = {
      bucket_name = { value = jsonencode("${var.test_context.run_id}-bucket") }
    }
  }
}

locals {
  bucket_outputs = meshstack_building_block.this.status.outputs
}

# Probes the bucket the way an application would: with the credentials the building block hands
# out, not the admin credentials its own run uses. A bucket policy that locks the application out
# still lets the run succeed, so only a real write catches it.
provider "aws" {
  alias      = "bucket_consumer"
  access_key = jsondecode(local.bucket_outputs["s3_access_key"].value)
  secret_key = jsondecode(local.bucket_outputs["s3_secret_access_key"].value)
  region     = "eu01"

  endpoints {
    s3 = "https://object.storage.eu01.onstackit.cloud"
  }

  skip_credentials_validation = true
  skip_region_validation      = true
  skip_requesting_account_id  = true
  skip_metadata_api_check     = true
  s3_use_path_style           = true
}

resource "aws_s3_object" "upload_probe" {
  provider = aws.bucket_consumer

  bucket  = jsondecode(local.bucket_outputs["bucket_name"].value)
  key     = "e2e-upload-probe.txt"
  content = "written by ${var.test_context.run_id}"
}
