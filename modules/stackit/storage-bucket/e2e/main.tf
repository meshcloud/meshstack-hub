variable "stackit_service_account_key" {
  type      = string
  nullable  = true
  sensitive = true
  default   = null
}

provider "stackit" {
  service_account_key = var.stackit_service_account_key
  experiments         = ["iam"]
}

variable "bbd_version_ref" {
  description = "If set, order an instance of this already-deployed BBD version instead of building one from hub source (smoke-test mode)."
  type        = any
  default     = null
}

variable "test_context" {
  type = object({
    hub_git_ref = optional(string)
    workspace   = string
    project     = optional(string)
    name_suffix = string

    fixtures = optional(object({
      stackit = optional(object({
        project_id     = string
        mesh_tenant_id = string
      }))
    }))
  })
  nullable = false
}

module "stackit_storage_bucket" {
  count  = var.bbd_version_ref == null ? 1 : 0
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
  version_ref = var.bbd_version_ref != null ? var.bbd_version_ref : module.stackit_storage_bucket[0].building_block_definition.version_ref
}

resource "meshstack_building_block_v2" "this" {
  wait_for_completion = true
  spec = {
    building_block_definition_version_ref = local.version_ref

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
