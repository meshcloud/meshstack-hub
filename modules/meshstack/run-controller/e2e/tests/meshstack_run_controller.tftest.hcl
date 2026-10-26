run "meshstack_run_controller" {
  assert {
    condition     = meshstack_building_block.run_controller.status.succeeded
    error_message = "run-controller building block expected SUCCEEDED, got health status ${meshstack_building_block.run_controller.status.health_status}, action ${meshstack_building_block.run_controller.status.action}"
  }

  assert {
    condition     = local.runner_ref.kind == "meshBuildingBlockRunner" && local.runner_ref.uuid != ""
    error_message = "run-controller building block expected output runner_ref to reference a meshBuildingBlockRunner, got ${jsondecode(meshstack_building_block.run_controller.status.outputs["runner_ref"].value)}"
  }

  assert {
    condition     = meshstack_building_block.noop.status.succeeded
    error_message = "noop building block expected SUCCEEDED, got health status ${meshstack_building_block.noop.status.health_status}, action ${meshstack_building_block.noop.status.action}"
  }

  assert {
    condition     = startswith(jsondecode(meshstack_building_block.noop.status.outputs["text"].value), "Hello, World! aws-cli/2")
    error_message = "noop building block expected output text to start with 'Hello, World! aws-cli/2', got ${jsondecode(meshstack_building_block.noop.status.outputs["text"].value)}"
  }

  assert {
    condition     = meshstack_building_block.github_workflow.status.succeeded
    error_message = "github workflow building block expected SUCCEEDED, got health status ${meshstack_building_block.github_workflow.status.health_status}, action ${meshstack_building_block.github_workflow.status.action}"
  }

  assert {
    condition     = meshstack_building_block.manual.status.succeeded
    error_message = "manual building block expected SUCCEEDED, got health status ${meshstack_building_block.manual.status.health_status}, action ${meshstack_building_block.manual.status.action}"
  }

  assert {
    condition     = jsondecode(meshstack_building_block.manual.status.outputs["text"].value) == "Hello, Manual World!"
    error_message = "manual building block expected output text to be 'Hello, Manual World!', got ${jsondecode(meshstack_building_block.manual.status.outputs["text"].value)}"
  }
}
