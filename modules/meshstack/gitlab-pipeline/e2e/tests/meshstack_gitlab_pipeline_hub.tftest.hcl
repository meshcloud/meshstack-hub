# Pins what a GitLab pipeline actually receives from meshStack. The two echo documents come from the
# same run: one is what the pipeline read from the run object, the other is what the trigger payload
# delivered. Where they disagree, that disagreement is the thing being asserted.

run "meshstack_gitlab_pipeline_hub" {
  assert {
    condition     = meshstack_building_block.this.status.status == "SUCCEEDED"
    error_message = "gitlab pipeline hub building block expected SUCCEEDED, got ${meshstack_building_block.this.status.status}"
  }

  assert {
    condition     = jsondecode(meshstack_building_block.this.status.outputs["behavior"].value) == "APPLY"
    error_message = "expected the pipeline to report an APPLY run"
  }

  assert {
    condition     = can(regex("^https?://", jsondecode(meshstack_building_block.this.status.outputs["pipeline_url"].value)))
    error_message = "expected the pipeline_url output to look like an URL"
  }

  # The three inputs that travel as GitLab pipeline inputs. Their types survive the round trip only
  # because the pipeline file declares them in spec:inputs.
  assert {
    condition     = jsondecode(meshstack_building_block.this.status.outputs["text"].value) == "Hello, World!"
    error_message = "text did not survive the pipeline-input channel"
  }

  assert {
    condition     = jsondecode(meshstack_building_block.this.status.outputs["num"].value) == 1
    error_message = "num did not survive the pipeline-input channel as an integer"
  }

  assert {
    condition     = jsondecode(meshstack_building_block.this.status.outputs["flag"].value) == true
    error_message = "flag did not survive the pipeline-input channel as a boolean"
  }

  # An input the consumer left blank and one whose condition does not hold are both sent as nothing
  # at all, rather than as an empty value.
  assert {
    condition     = !contains(keys(output.from_run_object), "optional_text")
    error_message = "an optional input left unset should not reach the run at all"
  }

  assert {
    condition     = !contains(keys(output.from_trigger), "conditional_text")
    error_message = "a conditional input whose condition does not hold should not reach the pipeline"
  }

  # The reason this module reads the run object rather than the trigger payload: only the run object
  # carries a list as a list. The trigger renders it with Kotlin's toString, which is not JSON.
  assert {
    condition     = output.from_run_object["multi_select"].value == ["multi1", "multi2"]
    error_message = "expected the run object to carry multi_select as a JSON array, got ${jsonencode(output.from_run_object["multi_select"].value)}"
  }

  assert {
    condition     = !can(jsondecode(output.from_trigger["multi_select"]))
    error_message = "the trigger payload rendered multi_select as JSON — the pipeline could read lists from it after all, so this module's advice needs revisiting"
  }

  # Both channels are represented, and meshStack reports which one each input took.
  assert {
    condition     = output.from_run_object["text"].isEnvironment == false && output.from_run_object["multi_select"].isEnvironment == true
    error_message = "expected text on the pipeline-input channel and multi_select on the variable channel"
  }

  # A file input has no file: it arrives as the MIME-typed base64 blob the definition declares.
  assert {
    condition     = output.from_run_object["file_yaml"].value == "data:application/yaml;base64,c29tZTogaW5wdXQKb3RoZXI6IHZhbHVlCg=="
    error_message = "file_yaml did not arrive as the declared data blob"
  }

  # meshStack encrypts a sensitive value for a runner to decrypt, and a pipeline holds no runner key.
  # If this ever flips, a pipeline can read secrets straight from the API and this module's guidance
  # about the variable channel is obsolete.
  assert {
    condition     = jsondecode(meshstack_building_block.this.status.outputs["sensitive_in_run_object_is_plaintext"].value) == false
    error_message = "the API served the sensitive input in the clear — the variable channel is no longer the only way to read one"
  }

  assert {
    condition     = output.from_trigger["sensitive_text"] == "<sensitive>" && output.from_run_object["sensitive_text"].isSensitive == true
    error_message = "expected the pipeline to redact the sensitive input in both echoes"
  }

  # Injected values are checked for shape, not for content, so the test does not tie itself to one
  # federation.
  assert {
    condition     = output.from_run_object["workspace_identifier"].value == meshstack_building_block.this.metadata.owned_by_workspace
    error_message = "workspace_identifier did not match the workspace the block belongs to"
  }

  assert {
    condition     = can(jsondecode(output.from_run_object["author"].value).identifier)
    error_message = "expected the AUTHOR input to carry a principal with an identifier"
  }
}
