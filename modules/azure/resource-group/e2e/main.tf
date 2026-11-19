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

variable "runner_switch" {
  type        = string
  default     = null
  description = "A step of the runner switch test in tests/azure_resource_group_runner_switch.tftest.hcl. `released_on_old_runner` releases version 1 with `old_runner`. `switched` creates a draft version 2 that uses `new_runner` and lists `old_runner` as trusted. Null runs the other tests, which set no runner."

  validation {
    condition     = var.runner_switch == null || contains(["released_on_old_runner", "switched"], coalesce(var.runner_switch, "-"))
    error_message = "runner_switch must be null, released_on_old_runner or switched."
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
  description = "The runner of version 1 in the runner switch test."
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
  description = "The runner of version 2 in the runner switch test."
}

locals {
  runner_switch = var.runner_switch != null
  switched      = var.runner_switch == "switched"
}

data "meshstack_building_block_runner" "old" {
  count = local.runner_switch ? 1 : 0

  metadata = {
    owned_by_workspace = var.old_runner.owned_by_workspace
  }
  spec = {
    display_name = var.old_runner.display_name
  }
}

data "meshstack_building_block_runner" "new" {
  count = local.runner_switch ? 1 : 0

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
    owning_workspace_identifier    = var.test_context.workspace
    tags                           = {}
    runner_ref                     = !local.runner_switch ? null : local.switched ? data.meshstack_building_block_runner.new[0].ref : data.meshstack_building_block_runner.old[0].ref
    additional_trusted_runner_refs = local.switched ? [data.meshstack_building_block_runner.old[0].ref] : []
  }

  hub = {
    git_ref   = var.test_context.hub_git_ref
    bbd_draft = var.runner_switch != "released_on_old_runner"
  }

  azure_tenant_id       = var.test_context.fixtures.azure.entra_tenant_id
  azure_subscription_id = var.test_context.fixtures.azure.subscription_uuid
  azure_scope           = local.azure_scope
  azure_location        = "westeurope"

  # Unique backplane name per test run so role definitions don't clash across concurrent/retried runs.
  backplane_name = "hub-e2e-rg-${var.test_context.name_suffix}"
}

data "meshstack_building_block_definition" "this" {
  count = local.runner_switch ? 1 : 0

  metadata = {
    uuid = module.resource_group.building_block_definition.uuid
  }
}

resource "meshstack_building_block" "this" {
  depends_on = [module.resource_group]

  wait_for_completion = true

  spec = {
    building_block_definition_version_ref = { uuid = local.runner_switch ? data.meshstack_building_block_definition.this[0].version_latest_release.uuid : module.resource_group.building_block_definition.version_ref.uuid }

    display_name = "smoke-test-resource-group-${var.test_context.name_suffix}"
    target_ref = {
      kind = "meshTenant"
      uuid = var.test_context.fixtures.azure.mesh_tenant_id
    }

    inputs = {
      workspace_identifier = { value = jsonencode(var.test_context.workspace) }
      project_identifier   = { value = jsonencode(local.switched ? "${local.project_identifier}-2" : local.project_identifier) }
    }
  }
}
