variable "test_context" {
  type = object({
    workspace   = string
    name_suffix = string
    hub_git_ref = string

    # Mode discriminator: set in foundation mode to order an already-deployed BBD version;
    # null in build-from-source mode, which builds the BBD from hub source.
    #
    # Only build-from-source mode is supported here: the STACKIT Project definition is
    # `use_in_landing_zones_only`, so it can only be exercised through the meshStack platform and
    # landing zone that the integration module provisions, and the invocation protocol has no way
    # to hand a foundation's platform and landing zone to the test.
    bbd_version_ref = optional(object({
      uuid = string
    }))

    # Cloud resource IDs needed to provision the backplane and place the projects it creates. This
    # building block *creates* the tenant's STACKIT project, so unlike other tenant-level blocks
    # there is no pre-existing `mesh_tenant_id` to target — the test creates its own tenant.
    fixtures = optional(object({
      stackit = object({
        organization_id = string
        project_id      = string
        # Dedicated, long-lived STACKIT folder that every project a smoke test creates is parented
        # under, so a project left behind by a failed teardown is identifiable by where it lives
        # rather than by a name pattern. STACKIT project deletion is an asynchronous hard delete
        # with no retention window, which makes that signal worth having.
        parent_container_id = string
      })
    }))
  })
  nullable = false
}

provider "stackit" {
  # Credentials are picked up from the environment: STACKIT_SERVICE_ACCOUNT_KEY_PATH for local
  # development, WIF in CI. Do not set service_account_key here — an explicit null argument
  # overrides the env-based credential discovery.
  experiments = ["iam"]
}

locals {
  # The meshStack project identifier is the STACKIT project name: the definition wires
  # `project_name` from PROJECT_IDENTIFIER. Carrying the run suffix here is therefore the only way
  # to make the STACKIT project this test creates traceable to its run.
  #
  # Two instance-level constraints shape it: identifiers longer than 30 characters are rejected as
  # too long, and the test instance additionally requires one to end in a stage suffix
  # (`-dev`/`-qa`/`-prod`), which is why this is not just a prefix plus the suffix.
  project_identifier = "smoke-prj-${var.test_context.name_suffix}-dev"

  # A platform identifier can never be reused in meshStack, not even after the platform is deleted,
  # so it must be unique per run. The `smoke-test-` prefix is what the cleanup tooling sweeps on.
  platform_identifier = "smoke-test-stk-${var.test_context.name_suffix}"

  # Tags the test workspace requires. The landing zone offers every value so it accepts the
  # project's narrower selection.
  landingzone_tags = {
    confidentiality = ["Public", "Internal", "Confidential"]
    environment     = ["dev", "qa", "prod"]
  }

  project_tags = {
    confidentiality = ["Public"]
    environment     = ["dev"]
  }
}

module "stackit_project" {
  count  = var.test_context.bbd_version_ref == null ? 1 : 0
  source = "../"

  meshstack = {
    owning_workspace_identifier = var.test_context.workspace
    tags = {
      # The test workspace makes these tags mandatory, and a landing zone has to offer every value
      # a project assigned to it may carry — meshStack rejects both objects otherwise.
      landingzone    = local.landingzone_tags
      building_block = {}
    }
    platform_identifier = local.platform_identifier
  }
  hub = {
    git_ref = var.test_context.hub_git_ref
    # Released, not draft — unlike every other e2e test. Nothing here orders the building block with
    # an explicit version ref: meshStack instantiates it itself as the landing zone's mandatory
    # building block, and resolving a definition's latest *released* version is the documented way
    # that happens. Releasing it takes one variable out of the picture; on its own it did not make
    # the mandatory building block run (see the PR description).
    bbd_draft = false
  }

  stackit_organization_id     = var.test_context.fixtures.stackit.organization_id
  stackit_project_id          = var.test_context.fixtures.stackit.project_id
  stackit_parent_container_id = var.test_context.fixtures.stackit.parent_container_id

  # Overriding the module default (`mesh-project`) keeps the backplane service account unique per
  # run, so concurrent or retried runs don't clash and a leaked one is traceable to its run. Short
  # prefix keeps the name within STACKIT's limits.
  stackit_service_account_name = "mprj-${var.test_context.name_suffix}"
}

locals {
  # Build-from-source only — see the `bbd_version_ref` comment above.
  integration = one(module.stackit_project)
}

resource "meshstack_project" "this" {
  metadata = {
    name               = local.project_identifier
    owned_by_workspace = var.test_context.workspace
  }

  spec = {
    display_name = "Smoke Test STACKIT Project ${var.test_context.name_suffix}"
    tags         = local.project_tags
  }
}

# The project is deliberately left without user bindings. `users` is a USER_PERMISSIONS input, and
# the building block's pre-run script adds every listed e-mail address to the STACKIT organization
# as a member. Real people's organization memberships are not something a smoke test may leak, so
# the test runs the pre-run script over an empty user list: it still executes, exchanges no token,
# and writes its summary, but grants nothing. The membership-add and project-role-assignment paths
# are consequently not covered here.

resource "meshstack_tenant" "this" {
  # Deleting the tenant is what deprovisions the mandatory building block, and that delete run
  # hard-deletes the STACKIT project. It has to finish while the backplane's WIF identity providers
  # still exist, or the run cannot authenticate and the project is orphaned with no way back.
  # `depends_on` keeps the backplane alive until the tenant is gone, and `wait_for_completion` makes
  # the provider block on the deletion (and, on create, until the project id has replicated back).
  depends_on          = [module.stackit_project]
  wait_for_completion = true

  metadata = {
    owned_by_workspace = var.test_context.workspace
    owned_by_project   = meshstack_project.this.metadata.name
  }

  spec = {
    platform_ref     = { uuid = local.integration.platform.uuid }
    landing_zone_ref = { name = local.integration.landingzone_names["default"] }
  }
}

# The building block is instantiated by meshStack as the landing zone's mandatory building block,
# not by OpenTofu, so its outputs are read back rather than owned.
data "meshstack_building_blocks" "tenant" {
  depends_on  = [meshstack_tenant.this]
  tenant_uuid = meshstack_tenant.this.metadata.uuid
}

output "project_building_block" {
  description = "The STACKIT Project building block meshStack instantiated for the test tenant."
  value       = one(data.meshstack_building_blocks.tenant.building_blocks)
}

output "platform_tenant_id" {
  description = "STACKIT project id the building block reported back to meshStack as the tenant's platform tenant id."
  value       = meshstack_tenant.this.spec.platform_tenant_id
}
