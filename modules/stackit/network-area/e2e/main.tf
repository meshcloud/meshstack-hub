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

    # Cloud resource IDs. Needed in build-from-source mode to provision the backplane: the service
    # account lives in the STACKIT project, but network areas (and the role assignment granting
    # access to them) are organization-scoped.
    fixtures = optional(object({
      stackit = object({
        organization_id = string
        project_id      = string
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

module "stackit_network_area" {
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
  # Short prefix keeps the generated service account name within STACKIT's name limits.
  stackit_service_account_name = "mna-${var.test_context.name_suffix}"
}

locals {
  version_ref = var.test_context.bbd_version_ref != null ? var.test_context.bbd_version_ref : module.stackit_network_area[0].building_block_definition.version_ref

  network_area_name = "smoke-test-na-${var.test_context.name_suffix}"
  # Ranges are picked from a block that is not used by any other network area in the test
  # organization — STACKIT rejects overlapping ranges across network areas.
  network_ranges   = ["10.234.0.0/16"]
  transfer_network = "10.235.0.0/24"
}

resource "meshstack_building_block" "this" {
  # Explicit dependency ensures the building block (and its delete run) is fully destroyed before
  # any backplane resources are torn down. Without this, OpenTofu destroys the WIF federated
  # identity providers in parallel with the delete run, causing 401s from the STACKIT provider.
  depends_on          = [module.stackit_network_area]
  wait_for_completion = true
  spec = {
    building_block_definition_version_ref = { uuid = local.version_ref.uuid }

    display_name = "smoke-test-stackit-network-area-${var.test_context.name_suffix}"
    target_ref = {
      kind = "meshWorkspace"
      name = var.test_context.workspace
    }

    inputs = {
      network_area_name = { value = jsonencode(local.network_area_name) }
      # CODE inputs carry HCL source as a string, hence the double encoding.
      network_ranges        = { value = jsonencode(jsonencode(local.network_ranges)) }
      transfer_network      = { value = jsonencode(local.transfer_network) }
      min_prefix_length     = { value = jsonencode(24) }
      max_prefix_length     = { value = jsonencode(28) }
      default_prefix_length = { value = jsonencode(28) }
      default_nameservers   = { value = jsonencode(jsonencode([])) }
      labels                = { value = jsonencode(jsonencode({})) }
    }
  }
}
