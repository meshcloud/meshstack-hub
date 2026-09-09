variable "test_context" {
  type = object({
    hub_git_ref = string
    workspace   = string
    name_suffix = string

    # meshStack rejects a meshObject that misses a mandatory tag, or carries a tag key the schema
    # does not define, so a test cannot guess either.
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

    fixtures = object({
      stackit = object({
        platform_uuid     = string
        landing_zone_name = string
      })
    })
  })
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

  # The module's default `expiry` only works on an instance whose tag schema defines it.
  workspace_expiry_tag_key = var.test_context.meshstack.tag_schema.expiry_key

  # A null default is what makes the input optional. The other value is never exercised: every
  # order sends its own TTL.
  workspace_ttl_days_default = var.ttl_optional ? null : 30

  # Names the definition and the API key the backplane mints, so a leaked one says which run left
  # it behind.
  display_name = "st-${var.test_context.name_suffix}"
}

output "version_ref" {
  value = module.workspace_starterkit.building_block_definition.version_ref
}
