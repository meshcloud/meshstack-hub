resource "stackit_network_area" "this" {
  organization_id = var.organization_id
  name            = var.network_area_name

  # Only set labels if there are actually labels to set
  labels = length(var.labels) > 0 ? var.labels : null
}

resource "stackit_network_area_region" "this" {
  organization_id = var.organization_id
  network_area_id = stackit_network_area.this.network_area_id

  ipv4 = {
    network_ranges        = [for r in var.network_ranges : { prefix = r }]
    transfer_network      = var.transfer_network
    min_prefix_length     = var.min_prefix_length
    max_prefix_length     = var.max_prefix_length
    default_prefix_length = var.default_prefix_length
    # STACKIT turns an empty list into null which results in an inconsistent result.
    default_nameservers = var.default_nameservers == [] ? null : var.default_nameservers
  }
}
