resource "restapi_object" "this" {
  lifecycle {
    enabled = !var.release_on_destroy
  }

  path = var.path

  # The API identifies an artifactory by a uuid it assigns, not by its name, so read, update and
  # destroy all address `artifactories/{uuid}`. The uuid comes from the create response, which is
  # why the provider sets `create_returns_object`. Naming `name` as the id instead sends the name
  # down those paths and the API rejects it: `parameter "artifactoryId" in path has an error:
  # minimum string length is 36`.
  id_attribute = "id"

  # PATCH, the only update this endpoint has, carries `proxy` and nothing else — a name is fixed for
  # the artifactory's life, so a new one means a new artifactory.
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
