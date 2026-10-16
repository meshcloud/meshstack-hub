resource "meshstack_project_user_binding" "this" {
  for_each = { for username, binding in var.bindings : username => binding.name if !binding.release_on_destroy }

  metadata = {
    name = each.value
  }

  role_ref = {
    name = "Project Admin"
  }

  target_ref = var.project

  subject = {
    name = each.key
  }
}

resource "meshstack_project_user_binding" "released" {
  for_each = { for username, binding in var.bindings : username => binding.name if binding.release_on_destroy }

  lifecycle {
    destroy         = false
    prevent_destroy = true
  }

  metadata = {
    name = each.value
  }

  role_ref = {
    name = "Project Admin"
  }

  target_ref = var.project

  subject = {
    name = each.key
  }
}

# Flipping the flag on existing state would replace the binding.
resource "terraform_data" "release_on_destroy" {
  for_each = var.bindings

  input = each.value.release_on_destroy

  lifecycle {
    ignore_changes = [input]

    postcondition {
      condition     = self.output == each.value.release_on_destroy
      error_message = "release_on_destroy cannot change once managed."
    }
  }
}
