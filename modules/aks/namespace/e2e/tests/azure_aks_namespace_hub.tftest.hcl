run "azure_aks_namespace_hub" {
  assert {
    condition     = meshstack_building_block.this.status.status == "SUCCEEDED"
    error_message = "aks/namespace hub building block expected SUCCEEDED, got ${meshstack_building_block.this.status.status}"
  }

  assert {
    condition     = startswith(jsondecode(meshstack_building_block.this.status.outputs["namespace_name"].value), "e2e-")
    error_message = "expected namespace_name to start with 'e2e-', got ${jsondecode(meshstack_building_block.this.status.outputs["namespace_name"].value)}"
  }
}
