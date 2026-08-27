run "building_block_noop_hub" {
  assert {
    condition     = meshstack_building_block.this.status.status == "SUCCEEDED"
    error_message = "noop hub building block expected SUCCEEDED, got ${meshstack_building_block.this.status.status}"
  }

  assert {
    condition     = jsondecode(meshstack_building_block.this.status.outputs["num"].value) == 1
    error_message = "noop hub building block expected output num to be 1, got ${jsondecode(meshstack_building_block.this.status.outputs["num"].value)}"
  }

  assert {
    condition     = startswith(jsondecode(meshstack_building_block.this.status.outputs["text"].value), "Hello, World! aws-cli/2")
    error_message = "noop hub building block expected output text to start with 'Hello, World! aws-cli/2', got ${jsondecode(meshstack_building_block.this.status.outputs["text"].value)}"
  }

  assert {
    condition     = jsondecode(meshstack_building_block.this.status.outputs["flag"].value) == true
    error_message = "noop hub building block expected output flag to be true, got ${jsondecode(meshstack_building_block.this.status.outputs["flag"].value)}"
  }

  assert {
    condition     = jsondecode(meshstack_building_block.this.status.outputs["resource_url"].value) == "https://hub.meshcloud.io/modules/meshstack/noop"
    error_message = "noop hub building block expected output resource_url to be 'https://hub.meshcloud.io/modules/meshstack/noop', got ${jsondecode(meshstack_building_block.this.status.outputs["resource_url"].value)}"
  }

  assert {
    condition = (
      jsondecode(meshstack_building_block.this.status.outputs["summary"].value)
      ==
      file("${path.root}/tests/building_block_noop_hub.summary.expected.md")
    )
    error_message = "noop hub building block expected output summary to match expected, got ${jsondecode(meshstack_building_block.this.status.outputs["summary"].value)}"
  }

  assert {
    # we have to exclude the user permissions inputs because several meshis hold role assignments on this workspace
    # and permissions may change, so we assert those separately below
    condition = (
      {
        for k, v in jsondecode(jsondecode(meshstack_building_block.this.status.outputs["debug_input_variables_json"].value)) :
        k => v
        if k != "user_permissions_json" && k != "user_permissions"
      }
      ==
      jsondecode(file("${path.root}/tests/building_block_noop_hub.debug_input_variables_json.expected.json"))
    )
    error_message = "noop hub building block expected output debug_input_variables_json to match expected (excluding user_permissions_json and user_permissions)"
  }

  # The workspace's members differ per meshStack instance, so these two assertions check that the
  # user permission binding is populated and well-shaped rather than naming a particular member —
  # pinning a specific user would tie this test to one federation.
  assert {
    condition = (
      length(jsondecode(jsondecode(meshstack_building_block.this.status.outputs["debug_input_variables_json"].value))["user_permissions"]) > 0
      &&
      # double decoding is required when user_permissions_json is passed as json
      length(jsondecode(jsondecode(jsondecode(meshstack_building_block.this.status.outputs["debug_input_variables_json"].value))["user_permissions_json"])) > 0
    )
    error_message = "expected both user permission bindings to be populated, got user_permissions=${jsonencode(jsondecode(jsondecode(meshstack_building_block.this.status.outputs["debug_input_variables_json"].value))["user_permissions"])} and user_permissions_json=${jsondecode(jsondecode(meshstack_building_block.this.status.outputs["debug_input_variables_json"].value))["user_permissions_json"]}"
  }

  # toset on both sides: comparing keys() (a list) to a tuple literal with == is always false,
  # because OpenTofu does not unify list and tuple types for equality.
  assert {
    condition = alltrue([
      for p in concat(
        jsondecode(jsondecode(meshstack_building_block.this.status.outputs["debug_input_variables_json"].value))["user_permissions"],
        jsondecode(jsondecode(jsondecode(meshstack_building_block.this.status.outputs["debug_input_variables_json"].value))["user_permissions_json"]),
      ) : toset(keys(p)) == toset(["email", "euid", "firstName", "lastName", "meshIdentifier", "roles", "username"])
    ])
    error_message = "expected every user permission to carry exactly the keys email, euid, firstName, lastName, meshIdentifier, roles, username, got user_permissions=${jsonencode(jsondecode(jsondecode(meshstack_building_block.this.status.outputs["debug_input_variables_json"].value))["user_permissions"])} and user_permissions_json=${jsondecode(jsondecode(meshstack_building_block.this.status.outputs["debug_input_variables_json"].value))["user_permissions_json"]}"
  }

  assert {
    condition = (
      jsondecode(jsondecode(meshstack_building_block.this.status.outputs["debug_input_files_json"].value))
      ==
      jsondecode(file("${path.root}/tests/building_block_noop_hub.debug_input_files_json.expected.json"))
    )
    error_message = "noop hub building block expected output debug_input_files_json to match expected, got ${jsondecode(meshstack_building_block.this.status.outputs["debug_input_files_json"].value)}"
  }
}
