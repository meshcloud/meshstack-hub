resource "restapi_object" "this" {
  lifecycle {
    enabled = !var.release_on_destroy
  }

  path = var.path

  # Read, update and delete address the uuid from the create response; the API rejects a name there.
  id_attribute = "id"

  # PATCH can only change `proxy`.
  force_new = ["name"]

  data = jsonencode({
    name = var.name
  })

  ignore_server_additions = true
}

resource "restapi_object" "released" {
  lifecycle {
    enabled         = var.release_on_destroy
    destroy         = false
    prevent_destroy = true
  }

  path         = var.path
  id_attribute = "id"
  force_new    = ["name"]

  data = jsonencode({
    name = var.name
  })

  ignore_server_additions = true
}

# Flipping the flag on existing state would replace the artifactory.
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
