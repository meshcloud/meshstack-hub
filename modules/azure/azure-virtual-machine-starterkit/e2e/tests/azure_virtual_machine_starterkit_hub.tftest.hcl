run "azure_virtual_machine_starterkit_hub" {
  assert {
    condition     = meshstack_building_block.this.status.status == "SUCCEEDED"
    error_message = "azure/azure-virtual-machine-starterkit hub building block expected SUCCEEDED, got ${meshstack_building_block.this.status.status}"
  }

  assert {
    condition     = length(jsondecode(meshstack_building_block.this.status.outputs["summary"].value)) > 0
    error_message = "expected a non-empty summary output from the starter kit"
  }
}
