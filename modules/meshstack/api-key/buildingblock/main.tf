locals {
  # meshStack passes an unset optional STRING input as "", not null. Normalise it so the resource
  # gets a real null and stays without an expiry, rather than an invalid empty date.
  expires_at = try(trimspace(var.expires_at), "") != "" ? var.expires_at : null
}

resource "meshstack_api_key" "this" {
  metadata = {
    owned_by_workspace = var.owned_by_workspace
  }

  spec = {
    display_name = var.display_name
    permissions  = var.permissions
    # Provider treats `expires_at` as optional; passing null leaves the key without an expiry.
    expires_at = local.expires_at
  }
}
