output "network_id" {
  value       = stackit_network.this.network_id
  description = "The UUID of the created STACKIT network."
}

output "network_cidr" {
  value       = stackit_network.this.ipv4_prefix
  description = "Allocated IPv4 CIDR block of the network."
}

output "network_url" {
  value       = "https://portal.stackit.cloud/network/networks/${stackit_network.this.network_id}/overview?project=${var.project_id}"
  description = "The deep link URL to access the network in the STACKIT portal."
}

output "summary" {
  description = "Summary of the created network."
  value = templatefile("${path.module}/SUMMARY.md.tftpl", {
    network_name = stackit_network.this.name
    network_id   = stackit_network.this.network_id
    network_cidr = stackit_network.this.ipv4_prefix
    network_url  = "https://portal.stackit.cloud/network/networks/${stackit_network.this.network_id}/overview?project=${var.project_id}"
  })
}
