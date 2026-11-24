# Outputs are read through `try` because a failed run reports none, and an assertion that indexes a
# missing output errors instead of failing, which buries the status assertion.

run "azure_aks" {
  assert {
    condition     = meshstack_building_block.this.status.succeeded
    error_message = "Building block run did not succeed: health status ${meshstack_building_block.this.status.health_status}, action ${meshstack_building_block.this.status.action}"
  }

  assert {
    condition     = try(jsondecode(meshstack_building_block.this.status.outputs["aks_cluster_name"].value), null) == "${var.test_context.run_id}-aks"
    error_message = "Expected aks_cluster_name ${var.test_context.run_id}-aks, got ${try(meshstack_building_block.this.status.outputs["aks_cluster_name"].value, "no such output")}."
  }

  assert {
    condition     = can(regex("^/subscriptions/[^/]+/resourceGroups/${var.test_context.run_id}-aks/providers/Microsoft\\.ContainerService/managedClusters/${var.test_context.run_id}-aks$", try(jsondecode(meshstack_building_block.this.status.outputs["aks_cluster_id"].value), "")))
    error_message = "Expected an AKS cluster resource ID in resource group ${var.test_context.run_id}-aks, got ${try(meshstack_building_block.this.status.outputs["aks_cluster_id"].value, "no such output")}."
  }

  assert {
    condition     = can(regex("^${var.test_context.run_id}-[a-z0-9]+\\.hcp\\.[a-z0-9]+\\.azmk8s\\.io$", try(jsondecode(meshstack_building_block.this.status.outputs["kube_api_server_fqdn"].value), "")))
    error_message = "Expected a public API server FQDN under the DNS prefix ${var.test_context.run_id}, got ${try(meshstack_building_block.this.status.outputs["kube_api_server_fqdn"].value, "no such output")}."
  }
}
