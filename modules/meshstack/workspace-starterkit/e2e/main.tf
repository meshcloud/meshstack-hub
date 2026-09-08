variable "test_context" {
  # Untyped: each mode module re-types it strictly, so every field it needs stays required.
  type     = any
  nullable = false

  validation {
    condition     = can(var.test_context.workspace) && can(var.test_context.name_suffix)
    error_message = "test_context must provide workspace and name_suffix."
  }

  validation {
    # Bound as owner of the workspace and project the building block creates, in both modes. A
    # username that does not exist in the instance fails the run's role bindings.
    condition     = can(var.test_context.owner_username)
    error_message = "test_context must provide owner_username."
  }

  validation {
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
  # Statically evaluated at `tofu init`, before any module is installed — so a foundation, which
  # already published the definition, never even resolves the hub build tree.
  mode = try(var.test_context.mode, "hub")

  # Only a definition built here can have an optional TTL input. A foundation published whatever it
  # published, and omitting a required input would fail the order rather than test anything.
  omit_ttl = local.mode == "hub" && var.ttl_optional

  # meshStack instances cap workspace identifiers at 16 characters, so the run timestamp goes in
  # without its century. `t`/`n` says whether this case ordered a TTL, keeping the two variants from
  # colliding inside one run — they share a name_suffix but not an identifier.
  run_id = "${var.ttl_optional ? "n" : "t"}-${substr(var.test_context.name_suffix, 2, 12)}"

  workspace_identifier = "w${local.run_id}"
  project_identifier   = "p${local.run_id}"

  workspace_ttl_days = 7
}

module "definition" {
  source = "./modes/${local.mode}"

  test_context = var.test_context
  run_id       = local.run_id
  ttl_optional = var.ttl_optional
}

resource "meshstack_building_block" "this" {
  # Orders teardown as well as create: one state holds the block and everything modes/hub built, so
  # the delete run finishes before the API key it authenticates with is destroyed.
  depends_on = [module.definition]

  wait_for_completion = true

  spec = {
    building_block_definition_version_ref = { uuid = module.definition.version_ref.uuid }

    display_name = "smoke-test-workspace-starterkit-${local.run_id}"
    target_ref = {
      kind = "meshWorkspace"
      name = var.test_context.workspace
    }

    # workspace_ttl_days is absent in the ttl_optional case: leaving an is_optional input unset is
    # the whole point — meshStack then sends no value and the building block falls back to its own
    # null default.
    inputs = merge(
      {
        workspace_identifier     = { value = jsonencode(local.workspace_identifier) }
        workspace_display_name   = { value = jsonencode("Smoke Test Starterkit ${local.run_id}") }
        workspace_owner_username = { value = jsonencode(var.test_context.owner_username) }
        payment_method_amount    = { value = jsonencode(100) }
        project_identifier       = { value = jsonencode(local.project_identifier) }
        project_display_name     = { value = jsonencode("Smoke Test Project ${local.run_id}") }
      },
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

# Two dates, not one: the building block stamps its own creation time minutes after this plan, so a
# run straddling midnight legitimately lands a day later. Null where no TTL was ordered.
output "expected_expiry_dates" {
  description = "The expiry dates the building block may report for the TTL this case ordered, or null where it ordered none."
  value = local.omit_ttl ? null : [
    for offset in [0, 24] :
    formatdate("YYYY-MM-DD", timeadd(plantimestamp(), "${offset + local.workspace_ttl_days * 24}h"))
  ]
}

output "expects_no_expiry" {
  description = "True when this case left the TTL blank, so the building block must report no expiry date at all."
  value       = local.omit_ttl
}
