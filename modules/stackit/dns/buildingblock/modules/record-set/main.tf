resource "stackit_dns_record_set" "this" {
  lifecycle {
    enabled = !var.release_on_destroy
  }

  project_id = var.project_id
  zone_id    = var.zone_id
  name       = var.name
  type       = "A"
  records    = var.records
  comment    = var.comment
}

resource "stackit_dns_record_set" "released" {
  lifecycle {
    enabled         = var.release_on_destroy
    destroy         = false
    prevent_destroy = true
  }

  project_id = var.project_id
  zone_id    = var.zone_id
  name       = var.name
  type       = "A"
  records    = var.records
  comment    = var.comment
}

# Flipping the flag on existing state would replace the record set.
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
