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
# registry robot credentials already do. The provider marks the key sensitive, so it is unwrapped
# with `nonsensitive` to surface it at all — otherwise OpenTofu refuses to export it. It is a
# convenience for first login — rotate or remove the key once the VM is set up. The resource null
# check gates the branch so the bring-your-own path never calls `nonsensitive` on a non-sensitive null.
output "ssh_private_key" {
  description = "Generated OpenSSH private key to log in as the default user. Null when a public key was supplied."
  value       = tls_private_key.this != null ? nonsensitive(tls_private_key.this.private_key_openssh) : null
}

output "ssh_key_pair_name" {
  description = "Name of the STACKIT key pair authorized on the VM."
  value       = stackit_key_pair.this.name
}
