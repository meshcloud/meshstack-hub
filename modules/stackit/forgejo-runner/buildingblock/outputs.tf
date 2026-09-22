output "runner_name" {
  value       = var.name
  description = "Name the runner registered under in Forgejo — also the value workflows target via runs-on labels."
}

output "server_id" {
  value       = stackit_server.this.server_id
  description = "ID of the STACKIT server hosting the runner."
}

output "public_ip" {
  value       = stackit_public_ip.this.ip
  description = "Public IP of the runner VM."
}

output "ssh_private_key" {
  value       = tls_private_key.this.private_key_openssh
  sensitive   = true
  description = "Break-glass SSH private key for the runner VM. Provisioning is fully automated; this is only for debugging a stuck registration."
}
