variable "test_context" {
  type = object({
    hub_git_ref = string
    workspace   = string
    name_suffix = string

    # Mode discriminator: set in foundation mode to order an already-deployed BBD version;
    # null in build-from-source mode, which builds the BBD from hub source.
    bbd_version_ref = optional(object({
      uuid = string
    }))
  })
  nullable = false
}

locals {
  key_display_name = "smoke-test-api-key-${var.test_context.name_suffix}"

  # APIKEY_LIST is part of the module's default grantable catalog, so the run token can mint a key
  # holding it — keeping the smoke test self-contained (no extra permissions to configure).
  key_permissions = ["APIKEY_LIST"]
}

module "meshstack_api_key" {
  count  = var.test_context.bbd_version_ref == null ? 1 : 0
  source = "../"

  meshstack = {
    owning_workspace_identifier = var.test_context.workspace
    tags                        = {}
  }
  hub = {
    git_ref   = var.test_context.hub_git_ref
    bbd_draft = true
  }
}

locals {
  version_ref = var.test_context.bbd_version_ref != null ? var.test_context.bbd_version_ref : module.meshstack_api_key[0].building_block_definition.version_ref
}

resource "meshstack_building_block" "this" {
  depends_on          = [module.meshstack_api_key]
  wait_for_completion = true

  spec = {
    building_block_definition_version_ref = { uuid = local.version_ref.uuid }

    display_name = local.key_display_name
    target_ref = {
      kind = "meshWorkspace"
      name = var.test_context.workspace
    }

    inputs = {
      owned_by_workspace = { value = jsonencode(var.test_context.workspace) }
      display_name       = { value = jsonencode(local.key_display_name) }
      permissions        = { value = jsonencode(local.key_permissions) }
      # Empty expiry: the smoke-test key never expires and is torn down with the building block.
      expires_at = { value = jsonencode("") }
    }
  }
}
