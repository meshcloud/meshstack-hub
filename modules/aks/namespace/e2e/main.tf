variable "test_context" {
  type = object({
    hub_git_ref = string
    workspace   = string
    name_suffix = string

    fixtures = object({
      azure = object({
        subscription_uuid = string
        entra_tenant_id   = string

        # An AKS cluster with Azure RBAC for Kubernetes enabled, which the smoke-test harness has to
        # provide: no other hub module needs a cluster.
        aks = object({
          cluster_name        = string
          resource_group_name = string
        })
      })
    })
  })

  nullable = false
}

module "aks_namespace" {
  source = "../"

  meshstack = {
    owning_workspace_identifier = var.test_context.workspace
    tags                        = {}
  }

  hub = {
    git_ref   = var.test_context.hub_git_ref
    bbd_draft = true
  }

  azure_tenant_id         = var.test_context.fixtures.azure.entra_tenant_id
  azure_subscription_id   = var.test_context.fixtures.azure.subscription_uuid
  azure_scope             = "/subscriptions/${var.test_context.fixtures.azure.subscription_uuid}"
  azure_location          = "westeurope"
  aks_cluster_name        = var.test_context.fixtures.azure.aks.cluster_name
  aks_resource_group_name = var.test_context.fixtures.azure.aks.resource_group_name

  # Unique backplane name per test run so role definitions don't clash across concurrent/retried runs.
  backplane_name = "hub-e2e-aksns-${var.test_context.name_suffix}"
}

resource "meshstack_building_block" "this" {
  depends_on = [module.aks_namespace]

  wait_for_completion = true

  spec = {
    building_block_definition_version_ref = module.aks_namespace.building_block_definition.version_ref

    display_name = "smoke-test-aks-namespace-${var.test_context.name_suffix}"
    target_ref = {
      kind = "meshWorkspace"
      name = var.test_context.workspace
    }

    inputs = {
      namespace_name = { value = jsonencode("e2e-${substr(var.test_context.name_suffix, 0, 10)}") }
    }
  }
}
