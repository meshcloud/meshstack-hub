output "public_ip" {
  value       = stackit_public_ip.this.ip
  description = "Public IP the VM is reachable on over SSH."
}

output "ssh_username" {
  value       = var.ssh_username
  description = "Login user for the VM, as shipped by the chosen image."
}

output "ssh_command" {
  value       = "ssh ${var.ssh_username}@${stackit_public_ip.this.ip}"
  description = "Ready-to-use SSH command once the generated private key is on disk (see ssh_private_key)."
}

output "ssh_private_key" {
  value       = tls_private_key.ssh.private_key_openssh
  sensitive   = true
  description = "Generated OpenSSH private key to log into the VM. Save it to a file, chmod 600, and pass it with ssh -i."
}

output "server_id" {
  value       = stackit_server.this.server_id
  description = "ID of the STACKIT server."
}

output "summary" {
  description = "Markdown summary shown in meshPanel after the run."
  value = templatefile("${path.module}/SUMMARY.md.tftpl", {
    name         = var.name
    public_ip    = stackit_public_ip.this.ip
    ssh_username = var.ssh_username
    machine_type = var.machine_type
  })
}
