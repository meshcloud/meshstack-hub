# Outputs are read through `try` because a failed run reports none, and an assertion that indexes a
# missing output errors instead of failing — which buries the status assertion.

run "stackit_server" {
  assert {
    condition     = meshstack_building_block.this.status.status == "SUCCEEDED"
    error_message = "Building block run did not succeed: ${meshstack_building_block.this.status.status}"
  }

  assert {
    condition     = can(regex("^(\\d{1,3}\\.){3}\\d{1,3}$", try(jsondecode(meshstack_building_block.this.status.outputs["public_ip"].value), "")))
    error_message = "Expected an IPv4 public_ip, got ${try(meshstack_building_block.this.status.outputs["public_ip"].value, "no such output")}."
  }

  assert {
    condition     = can(regex("^[0-9a-f-]{36}$", try(jsondecode(meshstack_building_block.this.status.outputs["server_id"].value), "")))
    error_message = "Expected a UUID server_id, got ${try(meshstack_building_block.this.status.outputs["server_id"].value, "no such output")}."
  }

  assert {
    condition     = try(jsondecode(meshstack_building_block.this.status.outputs["ssh_username"].value), null) == "ubuntu"
    error_message = "Expected ssh_username 'ubuntu', got ${try(meshstack_building_block.this.status.outputs["ssh_username"].value, "no such output")}."
  }

  assert {
    condition     = try(jsondecode(meshstack_building_block.this.status.outputs["ssh_command"].value), "") == "ssh ubuntu@${try(jsondecode(meshstack_building_block.this.status.outputs["public_ip"].value), "")}"
    error_message = "Expected ssh_command to target ubuntu@<public_ip>, got ${try(meshstack_building_block.this.status.outputs["ssh_command"].value, "no such output")}."
  }

  assert {
    condition     = startswith(try(jsondecode(meshstack_building_block.this.status.outputs["ssh_private_key"].value), ""), "-----BEGIN OPENSSH PRIVATE KEY-----")
    error_message = "Expected an OpenSSH private key in ssh_private_key output."
  }
}
