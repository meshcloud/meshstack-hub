variable "test_context" {
  type = object({
    workspace   = string
    run_id      = string
    hub_git_ref = string

    # Mode discriminator: set in foundation mode to order an already-deployed BBD version;
    # null in build-from-source mode, which builds the BBD from hub source.
    bbd_version_ref = optional(object({
      uuid = string
    }))

    # Cloud resource IDs. Needed in build-from-source mode to provision the backplane (the service
    # account lives in the STACKIT project, while its iam.service-account-admin / iam.member-admin
    # roles are organization-scoped) and, because this is a tenant-level building block, in both
    # modes for the target_ref tenant whose STACKIT project the service account is created in.
    fixtures = optional(object({
      stackit = object({
        organization_id = string
        project_id      = string
        mesh_tenant_id  = string
      })
    }))
  })
  nullable = false
}

variable "runner_switch" {
  type        = string
  default     = null
  description = "A step of the runner switch test in tests/stackit_service_account_runner_switch.tftest.hcl. `released_on_old_runner` releases version 1 with `old_runner`. `switched` creates a draft version 2 that uses `new_runner` and lists `old_runner` as trusted. Null runs the other tests, which set no runner."

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

provider "stackit" {
  # Credentials are picked up from the environment: STACKIT_SERVICE_ACCOUNT_KEY_PATH for local
  # development, WIF in CI. Do not set service_account_key here — an explicit null argument
  # overrides the env-based credential discovery.
  experiments = ["iam"]
}

module "stackit_service_account" {
  source = "../"

  lifecycle {
    enabled = var.test_context.bbd_version_ref == null
  }
  meshstack = {
    owning_workspace_identifier = var.test_context.workspace
    tags                        = {}
    runner_ref                  = !local.runner_switch ? null : local.switched ? data.meshstack_building_block_runner.new[0].ref : data.meshstack_building_block_runner.old[0].ref
    trusted_runner_refs         = local.switched ? [data.meshstack_building_block_runner.old[0].ref] : []
  }
  hub = {
    git_ref   = var.test_context.hub_git_ref
    bbd_draft = var.runner_switch != "released_on_old_runner"
  }

  bbd_display_name = "${var.test_context.run_id} STACKIT Service Account"

  stackit_organization_id = var.test_context.fixtures.stackit.organization_id
  stackit_project_id      = var.test_context.fixtures.stackit.project_id
  # The backplane service account carries a distinct suffix from the instance one below, so a
  # build-from-source run whose target tenant resolves to fixtures.project_id does not collide on
  # two service accounts of the same name in one project.
  stackit_service_account_name = "${var.test_context.run_id}-sabp"

  stackit_federation_backplane_email = module.stackit_service_account_federation.backplane_service_account_email
}

# Every service account grants this definition's backplane `editor`, so the test needs one, although
# it orders no federation.
module "stackit_service_account_federation" {
  source = "../../service-account-federation"

  lifecycle {
    enabled = var.test_context.bbd_version_ref == null
  }

  service_account_definition_ref = module.stackit_service_account.building_block_definition.ref

  meshstack = {
    owning_workspace_identifier = var.test_context.workspace
    tags                        = {}
  }
  hub = {
    git_ref   = var.test_context.hub_git_ref
    bbd_draft = true
  }

  bbd_display_name = "${var.test_context.run_id} STACKIT Service Account Federation"

  stackit_project_id           = var.test_context.fixtures.stackit.project_id
  stackit_service_account_name = "${var.test_context.run_id}-safb"
}

data "meshstack_building_block_definition" "this" {
  count = local.runner_switch ? 1 : 0

  metadata = {
    uuid = module.stackit_service_account.building_block_definition.uuid
  }
}

locals {
  hub_version_ref = local.runner_switch ? { uuid = data.meshstack_building_block_definition.this[0].version_latest_release.uuid } : { uuid = module.stackit_service_account.building_block_definition.version_ref.uuid }
  version_ref     = var.test_context.bbd_version_ref != null ? var.test_context.bbd_version_ref : local.hub_version_ref
}

resource "meshstack_building_block" "this" {
  # Explicit dependency ensures the building block (and its delete run) is fully destroyed before
  # any backplane resources are torn down. Without this, OpenTofu destroys the WIF federated
  # identity providers in parallel with the delete run, causing 401s from the STACKIT provider.
  depends_on          = [module.stackit_service_account]
  wait_for_completion = true
  spec = {
    building_block_definition_version_ref = local.version_ref

    display_name = "${var.test_context.run_id}-service-account"
    # The service account is created inside the STACKIT project backing this tenant; `project_id` is
    # a PLATFORM_TENANT_ID input meshStack resolves from the target tenant.
    target_ref = {
      kind = "meshTenant"
      uuid = var.test_context.fixtures.stackit.mesh_tenant_id
    }

    inputs = {
      service_account_name = { value = jsonencode("${var.test_context.run_id}-sa") }
      roles                = { value = jsonencode(jsonencode(local.switched ? ["reader", "editor"] : ["reader"])) }
    }
  }
}
