variable "test_context" {
  type     = any
  nullable = false

  validation {
    condition     = can(var.test_context.workspace) && can(var.test_context.name_suffix)
    error_message = "test_context must provide workspace and name_suffix."
  }

  validation {
    condition     = can(var.test_context.owner_username)
    error_message = "test_context must provide owner_username."
  }

  validation {
    condition     = can(var.test_context.meshstack.project_identifier_suffix)
    error_message = "test_context must provide meshstack.project_identifier_suffix."
  }

  validation {
    # `try` because `test_context` is untyped, so a hub run need not set `mode` at all.
    condition     = contains(["hub", "foundation"], try(var.test_context.mode, "hub"))
    error_message = "test_context.mode must be \"hub\" (the default) or \"foundation\"."
  }
}

variable "ttl_optional" {
  type        = bool
  default     = false
  description = "Order the building block without a TTL, against a definition whose TTL input is optional. Exercises expiry tracking switched off."
}

locals {
  # `try` because `test_context` is untyped, so a hub run need not set `mode` at all.
  mode = try(var.test_context.mode, "hub")

  # A foundation published its definition with whatever TTL default it chose, so only a definition
  # built here can have an optional input to leave blank.
  omit_ttl = local.mode == "hub" && var.ttl_optional

  # One letter of prefix, because meshStack caps workspace identifiers at 16 characters.
  workspace_identifier = "w${var.test_context.name_suffix}"

  # The instance decides what a project may be called; nothing can derive a name from its regex.
  project_identifier = "p${var.test_context.name_suffix}${var.test_context.meshstack.project_identifier_suffix}"

  workspace_ttl_days = 7
}

module "definition" {
  source = "./modes/${local.mode}"

  test_context = var.test_context
  ttl_optional = var.ttl_optional
}

resource "meshstack_building_block" "this" {
  depends_on = [module.definition]

  wait_for_completion = true

  spec = {
    building_block_definition_version_ref = { uuid = module.definition.version_ref.uuid }

    display_name = "st-${var.test_context.name_suffix}"
    target_ref = {
      kind = "meshWorkspace"
      name = var.test_context.workspace
    }

    inputs = merge(
      {
        workspace_identifier     = { value = jsonencode(local.workspace_identifier) }
        workspace_display_name   = { value = jsonencode("Smoke Test ${var.test_context.name_suffix}") }
        workspace_owner_username = { value = jsonencode(var.test_context.owner_username) }
        payment_method_amount    = { value = jsonencode(100) }
        project_identifier       = { value = jsonencode(local.project_identifier) }
        project_display_name     = { value = jsonencode("Project ${var.test_context.name_suffix}") }
      },
      # Leaving an is_optional input out is the case under test: meshStack then sends no value.
      local.omit_ttl ? {} : {
        workspace_ttl_days = { value = jsonencode(local.workspace_ttl_days) }
      }
    )
  }
}

output "expected_workspace_identifier" {
  description = "Identifier the building block should report for the workspace it created."
  value       = local.workspace_identifier
}

output "expected_project_identifier" {
  description = "Identifier the building block should report for the project it created."
  value       = local.project_identifier
}

output "expected_payment_method_identifier" {
  description = "Identifier the building block derives for the payment method, from the workspace identifier."
  value       = "${local.workspace_identifier}-payment-method"
}

output "expected_expiry_dates" {
  description = "The expiry dates the building block may report for the TTL this case ordered."

  # Two, because the block stamps its own creation time minutes after this plan: a run straddling
  # midnight lands a day later.
  value = [
    for offset in [0, 24] :
    formatdate("YYYY-MM-DD", timeadd(plantimestamp(), "${offset + local.workspace_ttl_days * 24}h"))
  ]
}

# The landing zone orders its own building block on the tenant this block creates, and that block
# has to be final before the tenant can be deleted. Read back to find out whether it is, by the
# time our own run reports SUCCEEDED.
data "meshstack_building_blocks" "tenant" {
  depends_on         = [meshstack_building_block.this]
  project_identifier = local.project_identifier
}

output "landing_zone_building_blocks" {
  description = "Statuses of the building blocks the landing zone ordered on the created tenant."
  value       = [for bb in data.meshstack_building_blocks.tenant.building_blocks : bb.status.status]
}
