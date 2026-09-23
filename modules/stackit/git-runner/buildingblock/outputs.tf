output "runner_name" {
  value       = var.name
  description = "Name the runner registered under in STACKIT Git."
}

output "server_id" {
  value       = stackit_server.this.server_id
  description = "ID of the STACKIT server hosting the runner."
}

output "egress_ip" {
  value       = local.create_network ? stackit_network.this.public_ip : ""
  description = "Public SNAT IP of the runner's network router, for allowlisting. Empty on an existing network."
}
