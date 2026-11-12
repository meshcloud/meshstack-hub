resource "kubernetes_namespace_v1" "this" {
  lifecycle {
    enabled = !var.release_on_destroy
  }

  metadata {
    name = var.name
  }
}

resource "kubernetes_namespace_v1" "released" {
  lifecycle {
    enabled         = var.release_on_destroy
    destroy         = false
    prevent_destroy = true
  }

  metadata {
    name = var.name
  }
}

# Flipping the flag on existing state would replace the namespace.
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
