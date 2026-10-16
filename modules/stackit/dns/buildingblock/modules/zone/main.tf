resource "stackit_dns_zone" "this" {
  lifecycle {
    enabled = !var.release_on_destroy
  }

  project_id    = var.project_id
  name          = var.name
  dns_name      = var.dns_name
  contact_email = var.contact_email
  type          = "primary"
  default_ttl   = var.default_ttl
}

resource "stackit_dns_zone" "released" {
  lifecycle {
    enabled         = var.release_on_destroy
    destroy         = false
    prevent_destroy = true
  }

  project_id    = var.project_id
  name          = var.name
  dns_name      = var.dns_name
  contact_email = var.contact_email
  type          = "primary"
  default_ttl   = var.default_ttl
}

# Flipping the flag on existing state would replace the zone.
resource "terraform_data" "release_on_destroy" {
  input = var.release_on_destroy

  lifecycle {
    ignore_changes = [input]

    postcondition {
      condition     = self.output == var.release_on_destroy
      error_message = "release_on_destroy cannot change once managed."
    }
  }
}
