# The one e2e file in this repo whose `run` blocks deliberately share state: each run is a change to
# the one before it rather than a fresh case. ../tag-inputs/README.md explains why, and what these
# runs do and do not prove.

variables {
  # Long enough for the run meshStack starts on its own to get out of the way. It competes with the
  # one this test triggers: it can reach a terminal state first and have its outputs read instead,
  # and meshStack rejects an update while a run is in flight.
  tag_settle_duration = "180s"
}

run "tag_inputs_resolve_on_create" {
  module {
    source = "./tag-inputs"
  }

  variables {
    scenario = "initial"
    # No building block exists yet, so there is no run of meshStack's to wait out.
    tag_settle_duration = "0s"
  }

  assert {
    condition     = output.building_block_status == "SUCCEEDED"
    error_message = "noop tag inputs building block expected SUCCEEDED, got ${output.building_block_status}"
  }

  assert {
    condition     = output.resolved_tags.project == ["cc-1000"]
    error_message = "expected the PROJECT tag to resolve to [\"cc-1000\"], got ${jsonencode(output.resolved_tags.project)}"
  }

  assert {
    condition     = output.resolved_tags.payment_method == ["pm-primary"]
    error_message = "expected the PAYMENT_METHOD tag to resolve to [\"pm-primary\"], got ${jsonencode(output.resolved_tags.payment_method)}"
  }

  # Two values, because a tag value is a list and a single-element list would not show that.
  assert {
    condition     = output.resolved_tags.landing_zone == ["lz-a", "lz-b"]
    error_message = "expected the LANDING_ZONE tag to resolve to [\"lz-a\", \"lz-b\"], got ${jsonencode(output.resolved_tags.landing_zone)}"
  }
}

run "tag_value_changes_resolve_on_the_next_run" {
  module {
    source = "./tag-inputs"
  }

  variables {
    scenario = "changed_values"
  }

  assert {
    condition     = output.building_block_status == "SUCCEEDED"
    error_message = "noop tag inputs building block expected SUCCEEDED after the tag edits, got ${output.building_block_status}"
  }

  assert {
    condition     = output.resolved_tags.project == ["cc-2000"]
    error_message = "expected the edited PROJECT tag to resolve to [\"cc-2000\"], got ${jsonencode(output.resolved_tags.project)}"
  }

  assert {
    condition     = output.resolved_tags.payment_method == ["pm-primary-edited"]
    error_message = "expected the edited PAYMENT_METHOD tag to resolve to [\"pm-primary-edited\"], got ${jsonencode(output.resolved_tags.payment_method)}"
  }

  assert {
    condition     = output.resolved_tags.landing_zone == ["lz-c"]
    error_message = "expected the edited LANDING_ZONE tag to resolve to [\"lz-c\"], got ${jsonencode(output.resolved_tags.landing_zone)}"
  }
}

run "reassigned_payment_method_resolves_its_own_tag" {
  module {
    source = "./tag-inputs"
  }

  variables {
    scenario = "reassigned_payment_method"
  }

  assert {
    condition     = output.building_block_status == "SUCCEEDED"
    error_message = "noop tag inputs building block expected SUCCEEDED after the reassignment, got ${output.building_block_status}"
  }

  # No tag was edited in this run — the project is funded from the substitute payment method instead,
  # so the input resolves a different object's tag.
  assert {
    condition     = output.resolved_tags.payment_method == ["pm-substitute"]
    error_message = "expected the reassigned PAYMENT_METHOD tag to resolve to [\"pm-substitute\"], got ${jsonencode(output.resolved_tags.payment_method)}"
  }

  # Unchanged, which is what makes the assertion above about the reassignment and nothing else.
  assert {
    condition     = output.resolved_tags.project == ["cc-2000"] && output.resolved_tags.landing_zone == ["lz-c"]
    error_message = "expected the PROJECT and LANDING_ZONE tags to be untouched by the reassignment, got project=${jsonencode(output.resolved_tags.project)} landing_zone=${jsonencode(output.resolved_tags.landing_zone)}"
  }
}
