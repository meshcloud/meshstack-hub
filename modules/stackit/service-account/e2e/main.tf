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
  }
  hub = {
    git_ref   = var.test_context.hub_git_ref
    bbd_draft = true
  }

  bbd_display_name = "${var.test_context.run_id} STACKIT Service Account"

  stackit_organization_id = var.test_context.fixtures.stackit.organization_id
  stackit_project_id      = var.test_context.fixtures.stackit.project_id
  # The backplane service account carries a distinct suffix from the instance one below, so a
  # build-from-source run whose target tenant resolves to fixtures.project_id does not collide on
  # two service accounts of the same name in one project.
  stackit_service_account_name = "${var.test_context.run_id}-sabp"
}

locals {
  version_ref = var.test_context.bbd_version_ref != null ? var.test_context.bbd_version_ref : module.stackit_service_account.building_block_definition.version_ref
}

resource "meshstack_building_block" "this" {
  # Explicit dependency ensures the building block (and its delete run) is fully destroyed before
  # any backplane resources are torn down. Without this, OpenTofu destroys the WIF federated
  # identity providers in parallel with the delete run, causing 401s from the STACKIT provider.
  depends_on          = [module.stackit_service_account]
  wait_for_completion = true
  spec = {
    building_block_definition_version_ref = { uuid = local.version_ref.uuid }

    display_name = "${var.test_context.run_id}-service-account"
    # The service account is created inside the STACKIT project backing this tenant; `project_id` is
    # a PLATFORM_TENANT_ID input meshStack resolves from the target tenant.
    target_ref = {
      kind = "meshTenant"
      uuid = var.test_context.fixtures.stackit.mesh_tenant_id
    }

    inputs = {
      service_account_name = { value = jsonencode("${var.test_context.run_id}-sa") }
      roles                = { value = jsonencode(jsonencode(["reader"])) }
    }
  }
}
