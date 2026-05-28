variable "test_context" {
  type = object({
    hub_git_ref = string
    workspace   = string
    name_suffix = string

    fixtures = object({
      azure = object({
        subscription_uuid = string
        entra_tenant_id   = string
      })
    })
  })
  nullable = false
}

locals {
  azure_scope = "/subscriptions/${var.test_context.fixtures.azure.subscription_uuid}"

  # backplane_name must be unique per test run to avoid role definition conflicts on retried runs.
  backplane_name = "e2e-aks-${var.test_context.name_suffix}"

  # cluster_name kept short to stay within 63-char AKS limit.
  cluster_name = "e2e-${substr(var.test_context.name_suffix, 0, 12)}"
}

module "aks" {
  source = "../"

  meshstack = {
    owning_workspace_identifier = var.test_context.workspace
    tags                        = {}
  }

  hub = {
    git_ref   = var.test_context.hub_git_ref
    bbd_draft = true
  }

  azure_tenant_id       = var.test_context.fixtures.azure.entra_tenant_id
  azure_subscription_id = var.test_context.fixtures.azure.subscription_uuid
  azure_scope           = local.azure_scope
  azure_hub_scope       = local.azure_scope
  azure_location        = "westeurope"

  backplane_name = local.backplane_name
}

resource "meshstack_building_block_v2" "this" {
  depends_on = [module.aks]

  wait_for_completion = true

  spec = {
    building_block_definition_version_ref = module.aks.building_block_definition.version_ref

    display_name = "smoke-test-aks-${var.test_context.name_suffix}"
    target_ref = {
      kind = "meshWorkspace"
      name = var.test_context.workspace
    }

    inputs = {
      resource_group_name     = { value_string = "rg-e2e-aks-${var.test_context.name_suffix}" }
      aks_cluster_name        = { value_string = local.cluster_name }
      location                = { value_string = "westeurope" }
      kubernetes_version      = { value_string = "1.33.0" }
      node_count              = { value_int = 1 }
      vm_size                 = { value_string = "Standard_A2_v2" }
      private_cluster_enabled = { value_bool = false }
    }
  }
}
