# Sync is the only variant: meshStack queues the pipeline, polls the run and maps each stage onto a
# step of the building block run.
#
# That also means the building block reports nothing about *what* the pipeline saw, so the pipeline
# carries its own assertions: ../../backplane/pipelines/azure-pipelines.yml fails its first stage
# unless every template parameter arrived non-empty. A SUCCEEDED run below is therefore also the
# assertion that meshStack delivered MESHSTACK_BEHAVIOR and the `environment` input.

run "meshstack_azure_devops_pipeline" {
  assert {
    condition     = meshstack_building_block.this.status.status == "SUCCEEDED"
    error_message = "azure devops pipeline hub building block expected SUCCEEDED, got ${meshstack_building_block.this.status.status}"
  }

  assert {
    condition     = length(try(meshstack_building_block.this.status.outputs, {})) == 0
    error_message = "azure devops pipeline hub building block declares no outputs, but reported some"
  }
}
