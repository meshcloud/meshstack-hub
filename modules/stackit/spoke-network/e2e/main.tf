variable "stackit_service_account_key" {
  type      = string
  nullable  = false
  sensitive = true
}

variable "test_context" {
  type = object({
    hub_git_ref = string
    workspace   = string
    project     = string
    name_suffix = string

    fixtures = object({
      stackit = object({
        project_id      = string
        mesh_tenant_id  = string
        organization_id = string
        network_area_id = string
      })
    })
  })
  nullable = false
}

provider "stackit" {
  service_account_key = var.stackit_service_account_key
  experiments         = ["iam"]
}

module "stackit_spoke_network" {
  source = "../"
  meshstack = {
    owning_workspace_identifier = var.test_context.workspace
    tags                        = {}
  }
  hub = {
    git_ref   = var.test_context.hub_git_ref
    bbd_draft = true
  }

  stackit_project_id      = var.test_context.fixtures.stackit.project_id
  stackit_organization_id = var.test_context.fixtures.stackit.organization_id
  network_area_id         = var.test_context.fixtures.stackit.network_area_id
}

resource "meshstack_building_block_v2" "this" {
  wait_for_completion = true
  spec = {
    building_block_definition_version_ref = module.stackit_spoke_network.building_block_definition.version_ref

    display_name = "smoke-test-spoke-network-${var.test_context.name_suffix}"
    target_ref = {
      kind = "meshTenant"
      uuid = var.test_context.fixtures.stackit.mesh_tenant_id
    }

    inputs = {
      network_prefix_length = { value_string = "28" }
    }
  }
}
