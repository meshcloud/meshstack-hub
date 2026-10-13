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

variable "ipam" {
  type        = bool
  default     = false
  description = "Exercise the variant that draws the address space from an IPAM pool instead of a typed CIDR range. Hub mode only: in foundation mode the published definition decides, see `local.ipam`."
}

locals {
  # `try` because `test_context` is untyped, so a hub run need not set `mode` at all.
  mode = try(var.test_context.mode, "hub")

  # A foundation publishes one definition, with or without a pool, and every test file orders
  # against it. `try` because a foundation without a pool need not set `ipam` at all.
  ipam = local.mode == "hub" ? var.ipam : try(var.test_context.ipam, false)
}

output "ipam" {
  description = "Whether the ordered spoke draws its address space from a pool."
  value       = local.ipam
}

output "expected_address_space" {
  description = "Regex the allocated address space has to match. The hub run's pool is 10.200.0.0/16; a foundation's pool is its own."
  value = (!local.ipam ? "^10\\.201\\.0\\.0/24$"
    : local.mode == "hub" ? "^10\\.200\\.[0-9]{1,3}\\.0/24$"
  : "^([0-9]{1,3}\\.){3}[0-9]{1,3}/24$")
}

module "definition" {
  source = "./modes/${local.mode}"

  test_context = var.test_context
  ipam         = var.ipam
}

resource "meshstack_building_block" "this" {
  # Also orders teardown: the delete run must finish before the backplane's WIF trust, the hub and
  # the pool are destroyed.
  depends_on = [module.definition]

  wait_for_completion = true

  spec = {
    building_block_definition_version_ref = { uuid = module.definition.version_ref.uuid }

    display_name = "${var.test_context.run_id} Azure Spoke Network"
    # `subscription_id` is a PLATFORM_TENANT_ID input and `name` a PROJECT_IDENTIFIER input, which
    # meshStack resolves from this tenant.
    target_ref = {
      kind = "meshTenant"
      uuid = var.test_context.fixtures.azure.mesh_tenant_id
    }

    # The definition asks for a CIDR range, or for a size when a pool hands out the range.
    inputs = merge(
      { for k, v in { address_space = { value = jsonencode("10.201.0.0/24") } } : k => v if !local.ipam },
      { for k, v in { ipam_prefix_length = { value = jsonencode("24") } } : k => v if local.ipam },
    )
  }
}
