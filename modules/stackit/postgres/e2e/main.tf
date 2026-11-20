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
    # `try` because `test_context` is untyped, so a hub run need not set `mode` at all.
    condition     = contains(["hub", "foundation"], try(var.test_context.mode, "hub"))
    error_message = "test_context.mode must be \"hub\" (the default) or \"foundation\"."
  }
}

locals {
  # `try` because `test_context` is untyped, so a hub run need not set `mode` at all.
  mode = try(var.test_context.mode, "hub")
}

module "definition" {
  source = "./modes/${local.mode}"

  test_context         = var.test_context
  database_only        = false
  existing_instance_id = null
}

resource "meshstack_building_block" "this" {
  # Also orders teardown: the delete run must finish before the service account's WIF trust is destroyed.
  depends_on = [module.definition]

  wait_for_completion = true

  spec = {
    building_block_definition_version_ref = module.definition.version_ref

    display_name = "${var.test_context.run_id}-postgres"
    target_ref = {
      kind = "meshTenant"
      uuid = var.test_context.fixtures.stackit.mesh_tenant_id
    }

    inputs = {
      instance_name = { value = jsonencode("${var.test_context.run_id}-pg") }
      # TEST-NET-1: the test opens no connection, so nothing needs to reach the instance.
      acl = { value = jsonencode(jsonencode(["192.0.2.0/24"])) }
    }
  }

  lifecycle {
    postcondition {
      condition     = self.status.succeeded
      error_message = "Building block ${self.metadata.uuid} did not succeed (health status ${self.status.health_status}, action ${self.status.action}). See its run in meshPanel."
    }
  }
}

# A second module call, because the instance block depends on all of `module.definition`.
module "database_definition" {
  source = "./modes/${local.mode}"

  test_context         = var.test_context
  database_only        = true
  existing_instance_id = jsondecode(meshstack_building_block.this.status.outputs["instance_id"].value)
}

resource "meshstack_building_block" "database" {
  # Also orders teardown: database block, its definition, then the instance block.
  depends_on = [module.database_definition]

  wait_for_completion = true

  spec = {
    building_block_definition_version_ref = module.database_definition.version_ref

    display_name = "${var.test_context.run_id}-postgres-db"
    target_ref = {
      kind = "meshTenant"
      uuid = var.test_context.fixtures.stackit.mesh_tenant_id
    }

    inputs = {}
  }
}
