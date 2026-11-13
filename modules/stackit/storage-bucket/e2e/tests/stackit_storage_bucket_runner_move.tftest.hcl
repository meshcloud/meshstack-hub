# Covers `meshstack.trusted_runner_refs`: a building block on an older definition version still
# signs in after the definition moves to another building block runner.
#
# The run blocks share state on purpose, because the subject is a change:
#   1. Version 1 is released on the old runner, and a building block is created on it.
#   2. The definition moves to the new runner, which creates version 2 as a draft, and the old runner
#      is listed as trusted. The bucket name of the first building block changes, so that it runs
#      again on version 1 and on the old runner. A second building block is created on version 2.
#
# The second run of the first building block is the proof. Without the trusted runner, the backplane
# would trust only the new runner, and that run would fail to sign in.
#
# Hub mode only. The test needs two runners with different issuers that both offer the Azure token.

run "released_on_old_runner" {
  variables {
    runner_move = "released_on_old_runner"
  }

  assert {
    condition     = data.meshstack_building_block_runner.old[0].spec.workload_identity_federation.issuer != data.meshstack_building_block_runner.new[0].spec.workload_identity_federation.issuer
    error_message = "the two runners must have different issuers"
  }

  assert {
    condition     = meshstack_building_block.this.status.succeeded
    error_message = "building block on the old runner expected SUCCEEDED, got health status ${meshstack_building_block.this.status.health_status}, action ${meshstack_building_block.this.status.action}"
  }
}

run "moved_with_the_old_runner_trusted" {
  variables {
    runner_move = "moved"
  }

  assert {
    condition     = meshstack_building_block.this.status.succeeded
    error_message = "building block on the old version expected SUCCEEDED after the move, got health status ${meshstack_building_block.this.status.health_status}, action ${meshstack_building_block.this.status.action}"
  }

  assert {
    condition     = jsondecode(meshstack_building_block.this.status.outputs["bucket_name"].value) == "${var.test_context.run_id}-bucket-2"
    error_message = "building block on the old version expected to run again after the move, got bucket ${jsondecode(meshstack_building_block.this.status.outputs["bucket_name"].value)}"
  }

  assert {
    condition     = meshstack_building_block.on_new_runner.status.succeeded
    error_message = "building block on the new runner expected SUCCEEDED, got health status ${meshstack_building_block.on_new_runner.status.health_status}, action ${meshstack_building_block.on_new_runner.status.action}"
  }

  assert {
    condition     = meshstack_building_block.on_new_runner.spec.building_block_definition_version_ref.uuid != meshstack_building_block.this.spec.building_block_definition_version_ref.uuid
    error_message = "the two building blocks must be on different versions"
  }
}
