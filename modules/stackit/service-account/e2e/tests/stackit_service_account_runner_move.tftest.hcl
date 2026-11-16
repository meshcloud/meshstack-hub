# Covers `meshstack.trusted_runner_refs`: a building block on an older definition version still
# signs in after the definition moves to another building block runner.
#
# The run blocks share state on purpose, because the subject is a change:
#   1. Version 1 is released on the old runner, and a building block is created on it.
#   2. The definition moves to the new runner, which creates version 2 as a draft, and the old runner
#      is listed as trusted. The roles of the building block change, so that it runs again on
#      version 1 and on the old runner.
#
# The second run of the building block is the proof. Without the trusted runner, the backplane would
# trust only the new runner, and that run would fail to sign in.
#
# There is no second building block on version 2: every building block of this definition grants the
# same role to the federation backplane, so two of them on one tenant collide.
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
    condition     = jsondecode(jsondecode(meshstack_building_block.this.spec.inputs["roles"].value)) == ["reader", "editor"]
    error_message = "building block on the old version expected to run again with the changed roles"
  }
}
