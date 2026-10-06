resource "stackit_git" "this" {
  lifecycle {
    enabled = !var.release_on_destroy
  }

  project_id = var.project_id
  name       = var.name
}

resource "stackit_git" "released" {
  lifecycle {
    enabled         = var.release_on_destroy
    destroy         = false
    prevent_destroy = true
  }

  project_id = var.project_id
  name       = var.name
}

# Flipping the flag on existing state would replace the instance.
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
