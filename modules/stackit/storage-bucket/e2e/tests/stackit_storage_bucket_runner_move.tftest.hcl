# The run blocks share state on purpose: the second one is a change to the first.
# ../runner-move/README.md explains why.

run "released_on_old_runner" {
  module {
    source = "./runner-move"
  }

  variables {
    scenario = "released_on_old_runner"
  }

  assert {
    condition     = output.runner_issuers.old != output.runner_issuers.new
    error_message = "the two runners must have different issuers, both have ${output.runner_issuers.old}"
  }

  assert {
    condition     = output.on_old_runner.status.succeeded
    error_message = "building block on the old runner expected SUCCEEDED, got health status ${output.on_old_runner.status.health_status}, action ${output.on_old_runner.status.action}"
  }
}

run "moved_with_the_old_runner_trusted" {
  module {
    source = "./runner-move"
  }

  variables {
    scenario = "moved"
  }

  assert {
    condition     = output.on_old_runner.status.succeeded
    error_message = "building block on the old version expected SUCCEEDED after the move, got health status ${output.on_old_runner.status.health_status}, action ${output.on_old_runner.status.action}"
  }

  assert {
    condition     = output.on_old_runner.bucket_name == "${var.test_context.run_id}-old-2"
    error_message = "building block on the old version expected to run again after the move, got bucket ${output.on_old_runner.bucket_name}"
  }

  assert {
    condition     = output.on_old_runner.version == run.released_on_old_runner.on_old_runner.version
    error_message = "building block on the old version must stay on its version"
  }

  assert {
    condition     = output.on_new_runner.status.succeeded
    error_message = "building block on the new runner expected SUCCEEDED, got health status ${output.on_new_runner.status.health_status}, action ${output.on_new_runner.status.action}"
  }

  assert {
    condition     = output.on_new_runner.version != output.on_old_runner.version
    error_message = "the two building blocks must be on different versions"
  }
}
