output "network_id" {
  value       = stackit_network.this.network_id
  description = "The UUID of the created STACKIT network."
}

output "network_cidr" {
  value       = stackit_network.this.ipv4_prefix
  description = "Allocated IPv4 CIDR block of the network."
}

output "summary" {
  description = "Summary of the created network."
  value = templatefile("${path.module}/SUMMARY.md.tftpl", {
    network_name = stackit_network.this.name
    network_id   = stackit_network.this.network_id
    network_cidr = stackit_network.this.ipv4_prefix
  })
}
