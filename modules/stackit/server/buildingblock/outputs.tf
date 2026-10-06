output "server_id" {
  value       = stackit_server.this.server_id
  description = "ID of the STACKIT server."
}

output "public_ip" {
  value       = stackit_public_ip.this.ip
  description = "Public IP of the VM. SSH in as ssh_username with the generated private key."
}

output "ssh_username" {
  value       = var.ssh_username
  description = "Default login user of the VM image, e.g. `ubuntu` on the Ubuntu image."
}

output "ssh_command" {
  value       = "ssh ${var.ssh_username}@${stackit_public_ip.this.ip}"
  description = "Ready-to-use SSH command once the generated private key is on disk."
}

output "ssh_private_key" {
  value       = tls_private_key.this.private_key_openssh
  sensitive   = true
  description = "Generated SSH private key (OpenSSH format) to log into the VM as ssh_username."
}

output "summary" {
  value       = "VM '${var.name}' is reachable at ${stackit_public_ip.this.ip}. Log in with `ssh ${var.ssh_username}@${stackit_public_ip.this.ip}` using the key from the ssh_private_key output."
  description = "Human-readable summary shown in meshPanel after the run."
}
