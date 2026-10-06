resource "meshstack_tenant" "this" {
  lifecycle {
    enabled         = !var.release_on_destroy
    prevent_destroy = var.prevent_destroy
  }

  wait_for_completion = var.wait_for_completion
  metadata            = var.metadata
  spec                = var.spec
}

resource "meshstack_tenant" "released" {
  lifecycle {
    enabled         = var.release_on_destroy
    destroy         = false
    prevent_destroy = true
  }

  wait_for_completion = var.wait_for_completion
  metadata            = var.metadata
  spec                = var.spec
}

# Flipping the flag on existing state would replace the tenant.
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
