locals {
  nameservers = var.ipv4_nameservers != null && var.ipv4_nameservers != "" ? split(",", var.ipv4_nameservers) : null
}

resource "stackit_routing_table" "this" {
  count           = var.firewall_next_hop_ip != null ? 1 : 0
  organization_id = var.organization_id
  network_area_id = var.network_area_id
  name            = "spoke-${var.project_id}"
  system_routes   = false
}

resource "stackit_routing_table_route" "this" {
  count            = var.firewall_next_hop_ip != null ? 1 : 0
  organization_id  = var.organization_id
  network_area_id  = var.network_area_id
  routing_table_id = stackit_routing_table.this[0].routing_table_id
  destination      = { type = "cidrv4", value = "0.0.0.0/0" }
  next_hop         = { type = "ipv4", value = var.firewall_next_hop_ip }
}

resource "stackit_network" "this" {
  project_id         = var.project_id
  name               = "spoke-routed"
  ipv4_prefix_length = var.network_prefix_length
  ipv4_nameservers   = local.nameservers
  routed             = true
  routing_table_id   = var.firewall_next_hop_ip != null ? stackit_routing_table.this[0].routing_table_id : null
}
