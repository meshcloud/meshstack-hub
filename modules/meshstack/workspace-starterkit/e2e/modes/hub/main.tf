# Builds the definition and its backplane from hub source, so a run exercises the API key this
# module mints rather than one an instance already had.
variable "test_context" {
  type = object({
    hub_git_ref = string
    workspace   = string

    # Tags the instance requires on every meshObject the building block creates, and the workspace
    # tag key it accepts an expiry date under. Not discoverable: meshStack answers a 409
    # TagValidation naming what is wrong, so the values come from the harness rather than a guess.
    meshstack = object({
      tag_schema = object({
        mandatory = object({
          workspace      = map(list(string))
          project        = map(list(string))
          payment_method = map(list(string))
        })
        expiry_key = string
      })
    })

    # The platform and landing zone the tenant is created on. A foundation's definition already
    # points at its own, which is why this is a hub-mode field.
    fixtures = object({
      stackit = object({
        platform_uuid     = string
        landing_zone_name = string
      })
    })
  })
  nullable = false
}

variable "run_id" {
  type     = string
  nullable = false
}

variable "ttl_optional" {
  type     = bool
  nullable = false
}

module "workspace_starterkit" {
  source = "../../../"

  meshstack = {
    owning_workspace_identifier = var.test_context.workspace

    # Not decoration: without the instance's mandatory tags the workspace create fails, and the
    # run with it.
    tags = {
      building_block = {}
      workspace      = var.test_context.meshstack.tag_schema.mandatory.workspace
      payment_method = var.test_context.meshstack.tag_schema.mandatory.payment_method
      project        = var.test_context.meshstack.tag_schema.mandatory.project
    }
  }
  hub = {
    git_ref   = var.test_context.hub_git_ref
    bbd_draft = true
  }

  platform_uuid     = var.test_context.fixtures.stackit.platform_uuid
  landing_zone_name = var.test_context.fixtures.stackit.landing_zone_name

  # The module defaults to `expiry`, which an instance only accepts if its tag schema defines it.
  workspace_expiry_tag_key = var.test_context.meshstack.tag_schema.expiry_key

  # The case under test: a null default is what makes the TTL input optional. The other value is
  # arbitrary — every order sends its own TTL, so a prefilled default is never exercised.
  workspace_ttl_days_default = var.ttl_optional ? null : 30

  # Names the definition and, through it, the API key the backplane mints — so the two cases do not
  # share a key in the workspace's key list, and a leaked one says which run left it behind.
  display_name = "smoke-test-workspace-starterkit-${var.run_id}"
}

output "version_ref" {
  value = module.workspace_starterkit.building_block_definition.version_ref
}
