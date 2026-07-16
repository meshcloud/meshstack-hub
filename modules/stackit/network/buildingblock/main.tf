resource "stackit_network" "this" {
  project_id         = var.project_id
  name               = var.network_name
  ipv4_prefix_length = var.network_prefix_length
  ipv4_nameservers   = length(var.ipv4_nameservers) > 0 ? var.ipv4_nameservers : null
  routed             = true
}
