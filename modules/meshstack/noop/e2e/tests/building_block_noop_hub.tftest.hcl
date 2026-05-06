# Tests the noop building block deployed via meshstack-hub module.
# Run individually: tofu test -filter=tests/building_block_noop_hub.tftest.hcl

run "building_block_noop_hub" {
  assert {
    condition     = meshstack_building_block_v2.this.status.status == "SUCCEEDED"
    error_message = "noop hub building block expected SUCCEEDED, got ${meshstack_building_block_v2.this.status.status}"
  }

  assert {
    condition     = meshstack_building_block_v2.this.status.outputs["num"].value_int == 1
    error_message = "noop hub building block expected output num to be 1, got ${meshstack_building_block_v2.this.status.outputs["num"].value_int}"
  }

  assert {
    condition     = meshstack_building_block_v2.this.status.outputs["text"].value_string == "Hello, World!"
    error_message = "noop hub building block expected output text to be 'Hello, World!', got ${meshstack_building_block_v2.this.status.outputs["text"].value_string}"
  }

  assert {
    condition     = meshstack_building_block_v2.this.status.outputs["flag"].value_bool == true
    error_message = "noop hub building block expected output flag to be true, got ${meshstack_building_block_v2.this.status.outputs["flag"].value_bool}"
  }

  assert {
    condition     = meshstack_building_block_v2.this.status.outputs["resource_url"].value_string == "https://hub.meshcloud.io/modules/meshstack/noop"
    error_message = "noop hub building block expected output resource_url to be 'https://hub.meshcloud.io/modules/meshstack/noop', got ${meshstack_building_block_v2.this.status.outputs["resource_url"].value_string}"
  }

  assert {
    condition = (
      meshstack_building_block_v2.this.status.outputs["summary"].value_string
      ==
      file("${path.root}/tests/building_block_noop_hub.summary.expected.md")
    )
    error_message = "noop hub building block expected output summary to match expected, got ${meshstack_building_block_v2.this.status.outputs["summary"].value_string}"
  }

  assert {
    # we have to exclude the user permissions inputs because several meshis hold role assignments on this workspace
    # and permissions may change, so we assert those separately below
    condition = (
      {
        for k, v in jsondecode(meshstack_building_block_v2.this.status.outputs["debug_input_variables_json"].value_code) :
        k => v
        if k != "user_permissions_json" && k != "user_permissions"
      }
      ==
      jsondecode(file("${path.root}/tests/building_block_noop_hub.debug_input_variables_json.expected.json"))
    )
    error_message = "noop hub building block expected output debug_input_variables_json to match expected (excluding user_permissions_json and user_permissions)"
  }

  assert {
    condition = contains(
      jsondecode(meshstack_building_block_v2.this.status.outputs["debug_input_variables_json"].value_code)["user_permissions"],
      jsondecode(file("${path.root}/tests/building_block_noop_hub.debug_input_variables_json_binding.expected.json"))
    )
    error_message = "could not find expected user permission"
  }

  assert {
    condition = contains(
      # double decoding is required when user_permissions_json is passed as json
      jsondecode(jsondecode(meshstack_building_block_v2.this.status.outputs["debug_input_variables_json"].value_code)["user_permissions_json"]),
      jsondecode(file("${path.root}/tests/building_block_noop_hub.debug_input_variables_json_binding.expected.json"))
    )
    error_message = "could not find expected user permission"
  }

  assert {
    condition = (
      jsondecode(meshstack_building_block_v2.this.status.outputs["debug_input_files_json"].value_code)
      ==
      jsondecode(file("${path.root}/tests/building_block_noop_hub.debug_input_files_json.expected.json"))
    )
    error_message = "noop hub building block expected output debug_input_files_json to match expected, got ${meshstack_building_block_v2.this.status.outputs["debug_input_files_json"].value_code}"
  }
}

