output "network_id" {
  value       = stackit_network.this.network_id
  description = "ID of the spoke network."
}

output "network_cidr" {
  value       = stackit_network.this.ipv4_prefix
  description = "Allocated IPv4 CIDR block of the spoke network."
}

output "routing_table_id" {
  value       = var.firewall_next_hop_ip != null ? stackit_routing_table.this[0].routing_table_id : null
  description = "ID of the custom routing table, or null if no firewall next-hop is configured."
}

output "summary" {
  description = "Summary with spoke network details."
  value = templatefile("${path.module}/SUMMARY.md.tftpl", {
    network_id        = stackit_network.this.network_id
    network_cidr      = stackit_network.this.ipv4_prefix
    network_area_id   = var.network_area_id
    has_routing_table = var.firewall_next_hop_ip != null
    routing_table_id  = var.firewall_next_hop_ip != null ? stackit_routing_table.this[0].routing_table_id : ""
  })
}
