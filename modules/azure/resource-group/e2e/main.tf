variable "test_context" {
  type = object({
    hub_git_ref = string
    workspace   = string
    name_suffix = string

    fixtures = object({
      azure = object({
        subscription_uuid = string
        entra_tenant_id   = string
        mesh_tenant_id    = string
      })
    })
  })

  nullable = false
}

variable "runner_move" {
  type        = string
  default     = null
  description = "Null runs the plain test. `released_on_old_runner` releases the definition on `old_runner`. `moved` moves it to `new_runner` and lists `old_runner` as trusted. See tests/azure_resource_group_runner_move.tftest.hcl."

  validation {
    condition     = var.runner_move == null || contains(["released_on_old_runner", "moved"], coalesce(var.runner_move, "-"))
    error_message = "runner_move must be null, released_on_old_runner or moved."
  }
}

variable "old_runner" {
  type = object({
    owned_by_workspace = string
    display_name       = string
  })
  default = {
    owned_by_workspace = "admin-customer"
    display_name       = "meshcloud-hosted Runner (deprecated)"
  }
  description = "The runner the definition starts on in the runner move test. It must offer the Azure token."
}

variable "new_runner" {
  type = object({
    owned_by_workspace = string
    display_name       = string
  })
  default = {
    owned_by_workspace = "admin-customer"
    display_name       = "meshcloud-hosted Runner (meshStack identity)"
  }
  description = "The runner the definition moves to in the runner move test. It must offer the Azure token and have another issuer than `old_runner`."
}

locals {
  runner_move = var.runner_move != null
  moved       = var.runner_move == "moved"
}

data "meshstack_building_block_runner" "old" {
  count = local.runner_move ? 1 : 0

  metadata = {
    owned_by_workspace = var.old_runner.owned_by_workspace
  }
  spec = {
    display_name = var.old_runner.display_name
  }
}

data "meshstack_building_block_runner" "new" {
  count = local.runner_move ? 1 : 0

  metadata = {
    owned_by_workspace = var.new_runner.owned_by_workspace
  }
  spec = {
    display_name = var.new_runner.display_name
  }
}

locals {
  azure_scope = "/subscriptions/${var.test_context.fixtures.azure.subscription_uuid}"

  # project_identifier is used in the resource group name: rg-<workspace>-<project>
  # Keep it short and valid: only lowercase alphanumeric and dashes.
  project_identifier = "e2e-${substr(var.test_context.name_suffix, 0, 10)}"
}

module "resource_group" {
  source = "../"

  meshstack = {
    owning_workspace_identifier = var.test_context.workspace
    tags                        = {}
    runner_ref                  = !local.runner_move ? null : local.moved ? data.meshstack_building_block_runner.new[0].ref : data.meshstack_building_block_runner.old[0].ref
    trusted_runner_refs         = local.moved ? [data.meshstack_building_block_runner.old[0].ref] : []
  }

  hub = {
    git_ref   = var.test_context.hub_git_ref
    bbd_draft = var.runner_move != "released_on_old_runner"
  }

  azure_tenant_id       = var.test_context.fixtures.azure.entra_tenant_id
  azure_subscription_id = var.test_context.fixtures.azure.subscription_uuid
  azure_scope           = local.azure_scope
  azure_location        = "westeurope"

  # Unique backplane name per test run so role definitions don't clash across concurrent/retried runs.
  backplane_name = "hub-e2e-rg-${var.test_context.name_suffix}"
}

data "meshstack_building_block_definition" "this" {
  count = local.runner_move ? 1 : 0

  metadata = {
    uuid = module.resource_group.building_block_definition.uuid
  }
}

resource "meshstack_building_block" "this" {
  depends_on = [module.resource_group]

  wait_for_completion = true

  spec = {
    building_block_definition_version_ref = { uuid = local.runner_move ? data.meshstack_building_block_definition.this[0].version_latest_release.uuid : module.resource_group.building_block_definition.version_ref.uuid }

    display_name = "smoke-test-resource-group-${var.test_context.name_suffix}"
    target_ref = {
      kind = "meshTenant"
      uuid = var.test_context.fixtures.azure.mesh_tenant_id
    }

    inputs = {
      workspace_identifier = { value = jsonencode(var.test_context.workspace) }
      project_identifier   = { value = jsonencode(local.moved ? "${local.project_identifier}-2" : local.project_identifier) }
    }
  }
}
