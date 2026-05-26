run "env_audit_hub" {
  assert {
    condition     = meshstack_building_block_v2.this.status.status == "SUCCEEDED"
    error_message = "env-audit building block expected SUCCEEDED, got ${meshstack_building_block_v2.this.status.status}"
  }
  assert {
    condition     = meshstack_building_block_v2.this.status.outputs["audit_result"].value_string == "Environment audit passed: only expected variables are present."
    error_message = "env-audit building block expected audit_result output to match, got ${meshstack_building_block_v2.this.status.outputs["audit_result"].value_string}"
  }
}
