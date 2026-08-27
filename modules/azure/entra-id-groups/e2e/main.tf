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

locals {
  # backplane_name must match ^[-a-z0-9]+$ and names both the backplane resource group and the UAMI.
  # UAMI names are limited to 24 characters, so keep the prefix short: "hub-e2e-eig-" (12) plus the
  # first 12 digits of the "YYYYMMDDhhmmss" suffix is exactly 24.
  backplane_name = "hub-e2e-eig-${substr(var.test_context.name_suffix, 0, 12)}"

  # Group display names are "<prefix>.<workspace>.<project>.<role>". The workspace and project come
  # from the meshStack tenant context and are the same on every run, so uniqueness has to come from
  # the prefix — otherwise a leaked group from an earlier run is indistinguishable from this one's.
  group_prefix = "hub-e2e-${var.test_context.name_suffix}"
}

module "entra_id_groups" {
  source = "../"

  meshstack = {
    owning_workspace_identifier = var.test_context.workspace
    tags                        = {}
  }

  hub = {
    git_ref   = var.test_context.hub_git_ref
    bbd_draft = true
  }

  azure_tenant_id = var.test_context.fixtures.azure.entra_tenant_id
  azure_location  = "westeurope"

  # The project members are B2B guests in the test tenant, so their user principal name is the
  # rewritten "<user>_<domain>#EXT#@<tenant>.onmicrosoft.com" form and a upn lookup misses them.
  # Their mail attribute keeps the original address, which is what "email" matches on.
  azure_user_lookup_attribute = "email"

  backplane_name = local.backplane_name
}

resource "meshstack_building_block" "this" {
  # Depend on the entire backplane to force correct resource ordering at the module boundary, not
  # just on individual backplane resources. Without this the UAMI's federated identity credential is
  # destroyed in parallel with the building block delete run, which then fails to authenticate and
  # leaves the Entra groups behind.
  depends_on = [module.entra_id_groups]

  wait_for_completion = true

  spec = {
    building_block_definition_version_ref = module.entra_id_groups.building_block_definition.version_ref

    display_name = "smoke-test-entra-id-groups-${var.test_context.name_suffix}"
    target_ref = {
      kind = "meshTenant"
      uuid = var.test_context.fixtures.azure.mesh_tenant_id
    }

    inputs = {
      prefix = { value = jsonencode(local.group_prefix) }

      # Exercise the default meshStack role set so the test covers the same group layout real
      # platforms get. workspace_identifier, project_identifier and users are injected by meshStack.
      project_roles = { value = jsonencode("admin,user,reader") }

      # Empty on purpose: the fixtures tenant has no Administrative Unit, and creating one per run
      # would leave directory-level litter behind on a failed teardown.
      administrative_unit_id = { value = jsonencode("") }
    }
  }
}
