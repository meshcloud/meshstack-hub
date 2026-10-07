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
  value       = <<-EOT
    # STACKIT VM `${var.name}`

    Your `${var.machine_type}` VM is up at **`${stackit_public_ip.this.ip}`**.

    Log in with the generated key (from the **SSH Private Key** output):

    ```sh
    # save the SSH Private Key output to a file first
    chmod 600 id_vm
    ssh -i id_vm ${var.ssh_username}@${stackit_public_ip.this.ip}
    ```
  EOT
}
