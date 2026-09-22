output "runner_name" {
  value       = var.name
  description = "Name the runner registered under in STACKIT Git — also the value workflows target via runs-on labels."
}

output "server_id" {
  value       = stackit_server.this.server_id
  description = "ID of the STACKIT server hosting the runner."
}

output "egress_ip" {
  value       = local.create_network ? stackit_network.this[0].public_ip : null
  description = "Public egress (SNAT) IP of the runner's network router. The VM itself has no inbound public IP. Use this to allowlist the runner on the Git instance. Null when attaching to an existing network."
}

output "ssh_private_key" {
  value       = tls_private_key.this.private_key_openssh
  sensitive   = true
  description = "Break-glass SSH private key for the runner VM. Provisioning is fully automated; this is only for debugging a stuck registration."
}
