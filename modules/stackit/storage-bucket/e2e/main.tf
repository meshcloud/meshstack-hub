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

variable "stackit_service_account_key" {
  type      = string
  sensitive = true
  nullable  = true
  default   = null
}

provider "stackit" {
  service_account_key = var.stackit_service_account_key
  experiments         = ["iam"]
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

  stackit_project_id           = var.test_context.fixtures.stackit.project_id
  stackit_service_account_name = "msb-${var.test_context.name_suffix}"
}

locals {
  version_ref = var.test_context.bbd_version_ref != null ? var.test_context.bbd_version_ref : module.stackit_storage_bucket[0].building_block_definition.version_ref
}

resource "meshstack_building_block_v2" "this" {
  wait_for_completion = true
  spec = {
    building_block_definition_version_ref = { uuid = local.version_ref.uuid }

    display_name = "smoke-test-stackit-storage-bucket-${var.test_context.name_suffix}"
    target_ref = {
      kind = "meshWorkspace"
      name = var.test_context.workspace
    }

    inputs = {
      bucket_name = { value_string = "smoke-test-bucket-${var.test_context.name_suffix}" }
    }
  }
}
