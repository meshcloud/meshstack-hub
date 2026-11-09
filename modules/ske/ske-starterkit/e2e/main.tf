variable "test_context" {
  # Untyped: each mode module re-types it strictly, so every field it needs stays required.
  type     = any
  nullable = false

  validation {
    condition     = can(var.test_context.workspace) && can(var.test_context.run_id) && (can(var.test_context.payment_method_identifier) || can(var.test_context.meshstack.tag_schema.mandatory.payment_method))
    error_message = "test_context must provide workspace, run_id and either payment_method_identifier or meshstack.tag_schema.mandatory.payment_method."
  }

  validation {
    # `try` because `test_context` is untyped, so a hub run need not set `mode` at all.
    condition     = contains(["hub", "foundation"], try(var.test_context.mode, "hub"))
    error_message = "test_context.mode must be \"hub\" (the default) or \"foundation\"."
  }
}

locals {
  # Statically evaluated at `tofu init`, before any module is installed — so a foundation, which
  # already published the definition, never even resolves the hub build tree.
  mode = try(var.test_context.mode, "hub")
}


module "definition" {
  source = "./modes/${local.mode}"

  test_context = var.test_context
}

locals {
  # A foundation hands in a payment method of its smoke workspace, because creating one needs
  # admin rights on the meshStack instance.
  payment_method_identifier = try(var.test_context.payment_method_identifier, null)

  payment_method_ref = local.payment_method_identifier != null ? { kind = "meshPaymentMethod", name = local.payment_method_identifier } : meshstack_payment_method.this.ref
}

resource "meshstack_payment_method" "this" {
  lifecycle {
    enabled = local.payment_method_identifier == null
  }

  metadata = {
    name               = "${var.test_context.run_id}-ske-starterkit-pm"
    owned_by_workspace = var.test_context.workspace
  }
  spec = {
    display_name = "${var.test_context.run_id} SKE Starterkit"
    tags         = var.test_context.meshstack.tag_schema.mandatory.payment_method
  }
}

resource "meshstack_building_block" "this" {
  depends_on = [module.definition]

  wait_for_completion = true
  spec = {
    building_block_definition_version_ref = module.definition.version_ref

    display_name = "${var.test_context.run_id}-ske-starterkit"
    target_ref = {
      kind = "meshWorkspace"
      name = var.test_context.workspace
    }

    inputs = {
      name           = { value = jsonencode(var.test_context.run_id) }
      payment_method = { value = jsonencode(local.payment_method_ref) }
    }
  }
}

# Probe the deployed dev + prod app endpoints: reaching SUCCEEDED means the app was deployed, but
# not that the ingress actually serves traffic with a valid, cert-manager-issued certificate. The
# script GETs the URL over TLS (verified against the system trust store) and retries while
# cert-manager issues the cert; the test asserts each returns 200. Referencing the BB outputs makes
# these data sources read after the building block completes.
data "external" "app_probe" {
  for_each = toset(["dev", "prod"])
  program  = ["python3", "${path.module}/probe_endpoint.py"]
  query = {
    url = try(jsondecode(meshstack_building_block.this.status.outputs["app_link_${each.key}"].value), "")
  }

  # When the building block above fails to apply, `status.outputs` is an empty map and indexing it
  # directly raised a bare "Invalid index" — a second, confusing error on top of the real one. Name
  # the actual cause instead.
  lifecycle {
    precondition {
      condition     = contains(keys(try(meshstack_building_block.this.status.outputs, {})), "app_link_${each.key}")
      error_message = "meshstack_building_block.this has no 'app_link_${each.key}' output (health status: ${try(meshstack_building_block.this.status.health_status, "unknown")}, action: ${try(meshstack_building_block.this.status.action, "unknown")}). It did not complete successfully — see the error above."
    }
  }
}
