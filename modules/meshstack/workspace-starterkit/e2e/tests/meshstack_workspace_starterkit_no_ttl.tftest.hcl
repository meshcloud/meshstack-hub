# Expiry tracking switched off, end to end: the definition declares the TTL input `is_optional`
# with no default, the order leaves it blank, and meshStack sends no value at all. What no mock can
# cover is that meshStack accepts such a definition and really omits the input — the building
# block's own null default is what then applies.
#
# Only hub mode builds the definition, so only hub mode can leave the field blank. In foundation
# mode this case degrades to ordering with a TTL, and the assertion below skips.

variables {
  ttl_optional = true
}

run "meshstack_workspace_starterkit_no_ttl" {
  assert {
    condition     = meshstack_building_block.this.status.status == "SUCCEEDED"
    error_message = "Building block run did not succeed: ${meshstack_building_block.this.status.status}"
  }

  assert {
    condition     = jsondecode(meshstack_building_block.this.status.outputs["workspace_identifier"].value) == output.expected_workspace_identifier
    error_message = "Reported workspace identifier is not the one that was ordered."
  }

  # No TTL means no date to report. The output is still declared, so the run has to produce it.
  assert {
    condition     = !output.expects_no_expiry || jsondecode(meshstack_building_block.this.status.outputs["workspace_expiry_date"].value) == null
    error_message = "A workspace ordered without a TTL must report no expiry date, got ${meshstack_building_block.this.status.outputs["workspace_expiry_date"].value}."
  }
}
