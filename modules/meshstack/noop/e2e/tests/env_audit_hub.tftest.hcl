run "env_audit_hub" {
  module {
    source = "./env-audit"
  }

  assert {
    condition     = meshstack_building_block_v2.this.status.status == "SUCCEEDED"
    error_message = "env-audit building block expected SUCCEEDED, got ${meshstack_building_block_v2.this.status.status}"
  }

  assert {
    condition     = length(setsubtract(toset(jsondecode(meshstack_building_block_v2.this.status.outputs["prerun_env_keys"].value_string)), toset(jsondecode(file("${path.root}/tests/env_audit_hub.allowed_env_keys.expected.json"))))) == 0
    error_message = "Unexpected prerun environment variables detected: ${meshstack_building_block_v2.this.status.outputs["prerun_env_keys"].value_string}"
  }

  assert {
    condition     = length(setsubtract(toset(jsondecode(meshstack_building_block_v2.this.status.outputs["apply_env_keys"].value_string)), toset(jsondecode(file("${path.root}/tests/env_audit_hub.allowed_env_keys.expected.json"))))) == 0
    error_message = "Unexpected apply-time environment variables detected: ${meshstack_building_block_v2.this.status.outputs["apply_env_keys"].value_string}"
  }
}
