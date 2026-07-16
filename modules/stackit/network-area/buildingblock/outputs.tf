output "network_area_id" {
  value       = stackit_network_area.this.network_area_id
  description = "The UUID of the created STACKIT network area."
}

output "network_area_name" {
  value       = stackit_network_area.this.name
  description = "The name of the created STACKIT network area."
}

output "network_ranges" {
  value       = var.network_ranges
  description = "IPv4 CIDR ranges available to projects within the network area."
}

output "transfer_network" {
  value       = var.transfer_network
  description = "IPv4 CIDR range used as the transfer network between the network area and connected networks."
}

output "summary" {
  description = "Summary of the created network area."
  value = templatefile("${path.module}/SUMMARY.md.tftpl", {
    network_area_id   = stackit_network_area.this.network_area_id
    network_area_name = stackit_network_area.this.name
    network_ranges    = var.network_ranges
    transfer_network  = var.transfer_network
  })
}
