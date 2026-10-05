output "server_id" {
  description = "ID of the STACKIT server."
  value       = stackit_server.this.server_id
}

output "public_ip" {
  description = "Public IP of the VM, for SSH. Empty when no public IP is attached."
  value       = stackit_public_ip.this != null ? stackit_public_ip.this.ip : ""
}

output "ssh_username" {
  description = "Default login user of the booted image. STACKIT Ubuntu images use `ubuntu`."
  value       = "ubuntu"
}

# Only set when the module generated the key pair; null when the caller brought their own public key.
#
# meshStack has no sensitive building block output, so this travels in the clear, as the container
# registry robot credentials already do. The provider marks the key sensitive, so `nonsensitive`
# unwraps it — otherwise OpenTofu refuses to export it. A `tls_private_key.this != null` gate cannot
# do the gating: the object carries sensitive attributes, so the comparison itself is sensitive and
# re-taints the whole output. `try` instead returns null in the bring-your-own case, where the
# resource is disabled and the attribute reference errors. It is a convenience for first login —
# rotate or remove the key once the VM is set up.
output "ssh_private_key" {
  description = "Generated OpenSSH private key to log in as the default user. Null when a public key was supplied."
  value       = try(nonsensitive(tls_private_key.this.private_key_openssh), null)
}

output "ssh_key_pair_name" {
  description = "Name of the STACKIT key pair authorized on the VM."
  value       = stackit_key_pair.this.name
}
