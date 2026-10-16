variable "test_context" {
  type     = any
  nullable = false

  validation {
    condition     = can(var.test_context.workspace) && can(var.test_context.run_id)
    error_message = "test_context must provide workspace and run_id."
  }

  validation {
    condition     = can(var.test_context.fixtures.stackit.mesh_tenant_id)
    error_message = "test_context must provide fixtures.stackit.mesh_tenant_id, the tenant to order the building block for."
  }

  validation {
    condition     = contains(["hub", "foundation"], try(var.test_context.mode, "hub"))
    error_message = "test_context.mode must be \"hub\" (the default) or \"foundation\"."
  }
}

locals {
  mode = try(var.test_context.mode, "hub")
}

module "definition" {
  source = "./modes/${local.mode}"

  test_context = var.test_context
}

resource "meshstack_building_block" "this" {
  depends_on = [module.definition]

  wait_for_completion = true

  spec = {
    building_block_definition_version_ref = module.definition.version_ref

    display_name = "${var.test_context.run_id}-service-account"
    target_ref = {
      kind = "meshTenant"
      uuid = var.test_context.fixtures.stackit.mesh_tenant_id
    }

    inputs = {
      service_account_name = { value = jsonencode("${var.test_context.run_id}-sa") }
      roles                = { value = jsonencode(jsonencode(["reader"])) }
    }
  }
}
