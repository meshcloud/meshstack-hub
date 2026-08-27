variable "test_context" {
  type = object({
    workspace   = string
    name_suffix = string
    hub_git_ref = string

    # Mode discriminator: set in foundation mode to order an already-deployed BBD version;
    # null in build-from-source mode, which builds the BBD from hub source.
    bbd_version_ref = optional(object({
      uuid = string
    }))

    # Cloud resource IDs. Needed in build-from-source mode to provision the backplane (the service
    # account lives in the STACKIT project, while the role assignment letting it manage networks is
    # organization-scoped) and, because this is a tenant-level building block, in both modes for the
    # target_ref tenant whose STACKIT project the network is created in.
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

module "stackit_network" {
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

  stackit_organization_id = var.test_context.fixtures.stackit.organization_id
  stackit_project_id      = var.test_context.fixtures.stackit.project_id
  # Overriding the module default (`mesh-network`) keeps the backplane service account unique per
  # run, so concurrent or retried runs don't clash and a leaked one is traceable to its run. Short
  # prefix keeps the name within STACKIT's limits.
  stackit_service_account_name = "mnet-${var.test_context.name_suffix}"
}

locals {
  version_ref = var.test_context.bbd_version_ref != null ? var.test_context.bbd_version_ref : module.stackit_network[0].building_block_definition.version_ref

  network_name = "smoke-test-net-${var.test_context.name_suffix}"
  # Smallest prefix the module's default min/max range allows, to keep the address space this test
  # consumes in the target project's network area as small as possible.
  network_prefix_length = 28
}

resource "meshstack_building_block" "this" {
  # Explicit dependency ensures the building block (and its delete run) is fully destroyed before
  # any backplane resources are torn down. Without this, OpenTofu destroys the WIF federated
  # identity providers in parallel with the delete run, causing 401s from the STACKIT provider.
  depends_on          = [module.stackit_network]
  wait_for_completion = true
  spec = {
    building_block_definition_version_ref = { uuid = local.version_ref.uuid }

    display_name = "smoke-test-stackit-network-${var.test_context.name_suffix}"
    # The network is created inside the STACKIT project backing this tenant; `project_id` is a
    # PLATFORM_TENANT_ID input meshStack resolves from the target tenant.
    target_ref = {
      kind = "meshTenant"
      uuid = var.test_context.fixtures.stackit.mesh_tenant_id
    }

    inputs = {
      network_name          = { value = jsonencode(local.network_name) }
      network_prefix_length = { value = jsonencode(local.network_prefix_length) }
      # CODE inputs carry HCL source as a string, hence the double encoding.
      ipv4_nameservers = { value = jsonencode(jsonencode([])) }
    }
  }
}
