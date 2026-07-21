variable "test_context" {
  type = object({
    hub_git_ref = string
    workspace   = string
    name_suffix = string

    # Mode discriminator: set in foundation mode to order an already-deployed BBD version;
    # null in build-from-source mode, which builds the child + starter-kit BBDs from hub source.
    bbd_version_ref = optional(object({
      uuid = string
    }))

    # Azure platform coordinates. Needed in build-from-source mode to provision the child VM
    # backplane and to let the starter kit create its project/tenant on a landing zone.
    fixtures = optional(object({
      azure = object({
        entra_tenant_id          = string
        subscription_uuid        = string
        full_platform_identifier = string
        landing_zone_identifier  = string
      })
    }))
  })
  nullable = false
}

locals {
  build_from_source = var.test_context.bbd_version_ref == null

  # Role definitions/assignments for the child VM backplane are scoped here. In the smoke-test
  # environment this is the fixture subscription; a real foundation scopes its backplane at the
  # management group that parents all landing-zone subscriptions (see the foundation deploy unit).
  azure_scope = local.build_from_source ? "/subscriptions/${var.test_context.fixtures.azure.subscription_uuid}" : null

  # VM project/name must satisfy ^[a-zA-Z0-9-]{0,24}$. name_suffix is a 14-digit timestamp.
  vm_name = "vm${var.test_context.name_suffix}"
}

# A throwaway SSH key so the Linux VM can be created (azurerm requires a valid RSA public key and
# disables password auth for Linux). The private key is never used — the smoke test only asserts the
# building block reaches SUCCEEDED.
resource "tls_private_key" "vm" {
  count     = local.build_from_source ? 1 : 0
  algorithm = "RSA"
  rsa_bits  = 4096
}

# Child Azure VM building block definition (composed by the starter kit).
module "azure_virtual_machine" {
  count  = local.build_from_source ? 1 : 0
  source = "../../azure-virtual-machine"

  meshstack = {
    owning_workspace_identifier = var.test_context.workspace
    tags                        = {}
  }
  hub = {
    git_ref   = var.test_context.hub_git_ref
    bbd_draft = true
  }

  azure_tenant_id = var.test_context.fixtures.azure.entra_tenant_id
  azure_scope     = local.azure_scope

  # Unique backplane name per run so role definitions don't clash across concurrent/retried runs.
  backplane_name = "hub-e2e-vm-${var.test_context.name_suffix}"
}

# Azure VM starter-kit building block definition (the module under test).
module "starterkit" {
  count  = local.build_from_source ? 1 : 0
  source = "../"

  meshstack = {
    owning_workspace_identifier = var.test_context.workspace
    tags                        = {}
  }
  hub = {
    git_ref   = var.test_context.hub_git_ref
    bbd_draft = true
  }

  full_platform_identifier         = var.test_context.fixtures.azure.full_platform_identifier
  landing_zone_identifier          = var.test_context.fixtures.azure.landing_zone_identifier
  azure_vm_definition_version_uuid = module.azure_virtual_machine[0].building_block_definition.version_ref.uuid
}

locals {
  version_ref = local.build_from_source ? module.starterkit[0].building_block_definition.version_ref : var.test_context.bbd_version_ref
}

resource "meshstack_building_block" "this" {
  # Force the whole composition (both BBDs + child backplane) to exist before the run, and to be
  # torn down only after the building block's delete run completes.
  depends_on = [module.starterkit, module.azure_virtual_machine]

  wait_for_completion = true

  spec = {
    building_block_definition_version_ref = { uuid = local.version_ref.uuid }

    display_name = "smoke-test-azure-vm-starterkit-${var.test_context.name_suffix}"
    target_ref = {
      kind = "meshWorkspace"
      name = var.test_context.workspace
    }

    inputs = {
      name                = { value = jsonencode(local.vm_name) }
      vm_location         = { value = jsonencode("westeurope") }
      vm_size             = { value = jsonencode("Standard_B1s") }
      vm_enable_public_ip = { value = jsonencode(false) }
      vm_ssh_public_key   = { value = jsonencode(local.build_from_source ? tls_private_key.vm[0].public_key_openssh : "") }
    }
  }
}
