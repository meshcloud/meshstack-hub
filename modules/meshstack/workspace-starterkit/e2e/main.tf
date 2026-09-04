variable "test_context" {
  type = object({
    workspace      = string
    name_suffix    = string
    hub_git_ref    = string
    owner_username = string

    # Mode discriminator: set in foundation mode to order an already-deployed BBD version;
    # null in build-from-source mode, which builds the BBD from hub source.
    bbd_version_ref = optional(object({
      uuid = string
    }))

    # Needed in build-from-source mode only: the platform/landing zone the workspace-starterkit's
    # own definition is built to create tenants on.
    fixtures = optional(object({
      stackit = object({
        platform_uuid     = string
        landing_zone_name = string
      })
    }))
  })
  nullable = false
}

# Admin-scoped meshStack API key/secret this building block authenticates with — needs ADM_*
# permissions (create workspaces/payment methods) beyond what the runner's own ephemeral token or
# the runner's default meshstack provider credentials grant. Only required in build-from-source
# mode: the smoke-test runner exports these as TF_VAR_meshstack_admin_api_key/secret; foundation
# mode omits them because the definition (and its baked-in admin credentials) is already deployed.
variable "meshstack_admin_api_key" {
  type      = string
  sensitive = true
  nullable  = true
  default   = null
}

variable "meshstack_admin_api_secret" {
  type      = string
  sensitive = true
  nullable  = true
  default   = null
}

locals {
  workspace_identifier = "e2e-wsk-${var.test_context.name_suffix}"
  project_identifier   = "e2e-wsk-proj-${var.test_context.name_suffix}"
}

module "workspace_starterkit" {
  count  = var.test_context.bbd_version_ref == null ? 1 : 0
  source = "../"

  meshstack = {
    owning_workspace_identifier = var.test_context.workspace
    tags = {
      building_block = {}
      workspace      = {}
      payment_method = {}
      project        = {}
    }
  }
  hub = {
    git_ref   = var.test_context.hub_git_ref
    bbd_draft = true
  }

  platform_uuid     = var.test_context.fixtures.stackit.platform_uuid
  landing_zone_name = var.test_context.fixtures.stackit.landing_zone_name

  meshstack_admin_api_key    = var.meshstack_admin_api_key
  meshstack_admin_api_secret = var.meshstack_admin_api_secret
}

locals {
  version_ref = var.test_context.bbd_version_ref != null ? var.test_context.bbd_version_ref : module.workspace_starterkit[0].building_block_definition.version_ref
}

resource "meshstack_building_block" "this" {
  depends_on          = [module.workspace_starterkit]
  wait_for_completion = true

  spec = {
    building_block_definition_version_ref = { uuid = local.version_ref.uuid }

    display_name = "smoke-test-workspace-starterkit-${var.test_context.name_suffix}"
    target_ref = {
      kind = "meshWorkspace"
      name = var.test_context.workspace
    }

    inputs = {
      workspace_identifier     = { value = jsonencode(local.workspace_identifier) }
      workspace_display_name   = { value = jsonencode("E2E Workspace Starterkit ${var.test_context.name_suffix}") }
      workspace_ttl_days       = { value = jsonencode(1) }
      workspace_owner_username = { value = jsonencode(var.test_context.owner_username) }
      payment_method_amount    = { value = jsonencode(10) }
      project_identifier       = { value = jsonencode(local.project_identifier) }
      project_display_name     = { value = jsonencode("E2E Workspace Starterkit ${var.test_context.name_suffix}") }
    }
  }
}

output "workspace_identifier" {
  value = local.workspace_identifier
}

output "project_identifier" {
  value = local.project_identifier
}
