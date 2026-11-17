# Version 2 of the definition uses a different building block runner than version 1. A building
# block on version 1 must still run, because `meshstack.trusted_runner_refs` lists the old runner.
#
# The two run blocks use one state:
#   1. The test releases version 1 with the old runner and creates a building block on it.
#   2. A draft version 2 uses the new runner, and the test lists the old runner as trusted. The roles of
#      the building block change, which starts a run on version 1 with the old runner.
#
# The run in step 2 fails if the cloud accepts only the tokens of the new runner.
# The test starts no run on version 2, so it does not check the tokens of the new runner.
#
# Version 2 gets no building block of its own. Every building block of this definition grants the
# same role to the federation backplane. Two of them on one tenant would conflict.
#
# Hub mode only.

run "released_on_old_runner" {
  variables {
    runner_switch = "released_on_old_runner"
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

run "switched_with_the_old_runner_trusted" {
  variables {
    runner_switch = "switched"
  }

  assert {
    condition     = meshstack_building_block.this.status.succeeded
    error_message = "building block on the old version expected SUCCEEDED after the switch, got health status ${meshstack_building_block.this.status.health_status}, action ${meshstack_building_block.this.status.action}"
  }

  assert {
    condition     = jsondecode(jsondecode(meshstack_building_block.this.spec.inputs["roles"].value)) == ["reader", "editor"]
    error_message = "building block on the old version expected to run again with the changed roles"
  }
}
