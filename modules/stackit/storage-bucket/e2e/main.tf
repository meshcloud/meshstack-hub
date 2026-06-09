variable "stackit_service_account_key" {
  type      = string
  nullable  = false
  sensitive = true
}

provider "stackit" {
  service_account_key = var.stackit_service_account_key
  experiments         = ["iam"]
}

variable "test_context" {
  type = object({
    hub_git_ref = string
    workspace   = string
    project     = string
    name_suffix = string

    fixtures = object({
      stackit = object({
        project_id     = string
        mesh_tenant_id = string
      })
    })
  })
  nullable = false
}

module "stackit_storage_bucket" {
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
  stackit_service_account_name = "mesh-storage-bucket-${var.test_context.name_suffix}"
}

resource "meshstack_building_block_v2" "this" {
  wait_for_completion = true
  spec = {
    building_block_definition_version_ref = module.stackit_storage_bucket.building_block_definition.version_ref

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
