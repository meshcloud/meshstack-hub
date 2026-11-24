variable "test_context" {
  type     = any
  nullable = false

  validation {
    condition     = can(var.test_context.workspace) && can(var.test_context.run_id)
    error_message = "test_context must provide workspace and run_id."
  }

  validation {
    condition     = can(var.test_context.fixtures.azure.mesh_tenant_id)
    error_message = "test_context must provide fixtures.azure.mesh_tenant_id, the tenant to order the building block for."
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

  test_context = var.test_context
}

resource "tls_private_key" "ssh" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "meshstack_building_block" "this" {
  # Also orders teardown: the delete run must finish before the backplane's WIF trust and the
  # network are destroyed.
  depends_on = [module.definition]

  wait_for_completion = true

  spec = {
    building_block_definition_version_ref = module.definition.version_ref

    display_name = "${var.test_context.run_id} Azure VM Scale Set"
    # `subscription_id` is a PLATFORM_TENANT_ID input, which meshStack resolves from this tenant.
    target_ref = {
      kind = "meshTenant"
      uuid = var.test_context.fixtures.azure.mesh_tenant_id
    }

    inputs = {
      vmss_name                = { value = jsonencode(var.test_context.run_id) }
      resource_group_name      = { value = jsonencode("${var.test_context.run_id}-vmss") }
      vnet_resource_group_name = { value = jsonencode(module.definition.network.resource_group_name) }
      vnet_name                = { value = jsonencode(module.definition.network.vnet_name) }
      subnet_name              = { value = jsonencode(module.definition.network.subnet_name) }
      ssh_public_key           = { value = jsonencode(tls_private_key.ssh.public_key_openssh) }
      instances                = { value = jsonencode(1) }
      enable_autoscaling       = { value = jsonencode(true) }
      min_instances            = { value = jsonencode(1) }
      max_instances            = { value = jsonencode(1) }
    }
  }
}
