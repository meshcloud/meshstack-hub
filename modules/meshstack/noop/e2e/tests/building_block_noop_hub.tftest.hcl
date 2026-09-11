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
    # optional_text is intentionally left out of the building block's inputs (see e2e/main.tf), so
    # this asserts the Terraform variable's own default ("tf-default-value") flows through as the output.
    condition     = jsondecode(meshstack_building_block.this.status.outputs["optional_text"].value) == "tf-default-value"
    error_message = "noop hub building block expected output optional_text to fall back to the Terraform variable default 'tf-default-value', got ${jsondecode(meshstack_building_block.this.status.outputs["optional_text"].value)}"
  }

  assert {
    condition     = jsondecode(meshstack_building_block.this.status.outputs["resource_url"].value) == "https://hub.meshcloud.io/modules/meshstack/noop"
    error_message = "noop hub building block expected output resource_url to be 'https://hub.meshcloud.io/modules/meshstack/noop', got ${jsondecode(meshstack_building_block.this.status.outputs["resource_url"].value)}"
  }

  assert {
    # conditional_text is only asked for while its `condition` (input.flag == true) holds, which the
    # building block's inputs in e2e/main.tf satisfy.
    condition     = jsondecode(meshstack_building_block.this.status.outputs["conditional_text"].value) == "Shown because flag is true"
    error_message = "noop hub building block expected output conditional_text to be 'Shown because flag is true', got ${jsondecode(meshstack_building_block.this.status.outputs["conditional_text"].value)}"
  }

  assert {
    # hidden_conditional_text is intentionally left out of the building block's inputs (see
    # e2e/main.tf): its condition (input.flag == false) never holds while flag is true, so
    # meshPanel hides it, meshStack sends no value for it, and this asserts the Terraform
    # variable's own default flows through as the output, exactly like optional_text.
    condition     = jsondecode(meshstack_building_block.this.status.outputs["hidden_conditional_text"].value) == "tf-default-value"
    error_message = "noop hub building block expected output hidden_conditional_text to fall back to the Terraform variable default 'tf-default-value', got ${jsondecode(meshstack_building_block.this.status.outputs["hidden_conditional_text"].value)}"
  }

  assert {
    # deploy_settings is a CODE-type output (see meshstack_integration.tf), so it round-trips
    # through meshStack as JSON text just like debug_input_variables_json below: one jsondecode()
    # unwraps the provider's own value encoding, a second unwraps the CODE text into the object.
    # Compared via jsonencode() on both sides: a raw `==` between a jsondecode()'d value and an HCL
    # object/list literal can spuriously fail on OpenTofu's tuple/object type unification even when
    # the values are identical, so canonical JSON strings are compared instead.
    condition = (
      jsonencode(jsondecode(jsondecode(meshstack_building_block.this.status.outputs["deploy_settings"].value)))
      ==
      jsonencode({ greeting = "Hello from e2e", shout = true })
    )
    error_message = "noop hub building block expected output deploy_settings to be {greeting = \"Hello from e2e\", shout = true}, got ${jsonencode(jsondecode(jsondecode(meshstack_building_block.this.status.outputs["deploy_settings"].value)))}"
  }

  assert {
    # tag_value is sourced from the meshstack_workspace_tag set up in e2e/main.tf, not from the
    # building block's own inputs. It's a CODE-type output too, so it needs the same double
    # jsondecode() as deploy_settings above.
    condition = (
      jsonencode(jsondecode(jsondecode(meshstack_building_block.this.status.outputs["tag_value"].value)))
      ==
      jsonencode(["e2e-tag-value"])
    )
    error_message = "noop hub building block expected output tag_value to be [\"e2e-tag-value\"], got ${jsonencode(jsondecode(jsondecode(meshstack_building_block.this.status.outputs["tag_value"].value)))}"
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
    # Inputs meshStack fills in from the instance (workspace members, the ordering principal, the
    # workspace identifier) differ per meshStack instance, so they are asserted separately below.
    condition = (
      {
        for k, v in jsondecode(jsondecode(meshstack_building_block.this.status.outputs["debug_input_variables_json"].value)) :
        k => v
        if !contains(["user_permissions", "user_permissions_json", "author", "workspace_identifier"], k)
      }
      ==
      jsondecode(file("${path.root}/tests/building_block_noop_hub.debug_input_variables_json.expected.json"))
    )
    error_message = "noop hub building block expected output debug_input_variables_json to match expected (excluding the instance-dependent inputs)"
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

  assert {
    condition     = jsondecode(meshstack_building_block.this.status.outputs["operator_text"].value) == "Set by the platform operator"
    error_message = "noop hub building block expected output operator_text to be 'Set by the platform operator', got ${jsondecode(meshstack_building_block.this.status.outputs["operator_text"].value)}"
  }

  # WORKSPACE_IDENTIFIER is injected by meshStack, so this checks it against the workspace the
  # provider reports for the block rather than pinning one instance's workspace name.
  assert {
    condition     = jsondecode(meshstack_building_block.this.status.outputs["workspace_identifier"].value) == meshstack_building_block.this.metadata.owned_by_workspace
    error_message = "expected output workspace_identifier to be ${meshstack_building_block.this.metadata.owned_by_workspace}, got ${jsondecode(meshstack_building_block.this.status.outputs["workspace_identifier"].value)}"
  }

  # AUTHOR resolves to whoever ordered the block — the test's own API key here, a real user in
  # meshPanel — so this asserts the shape and that the principal is identified, not who it is.
  assert {
    condition = (
      toset(keys(jsondecode(jsondecode(meshstack_building_block.this.status.outputs["author"].value)))) ==
      toset(["displayName", "email", "euid", "identifier", "type", "username"])
      &&
      jsondecode(jsondecode(meshstack_building_block.this.status.outputs["author"].value))["identifier"] != ""
    )
    error_message = "expected output author to carry an identified principal, got ${jsondecode(meshstack_building_block.this.status.outputs["author"].value)}"
  }
}
