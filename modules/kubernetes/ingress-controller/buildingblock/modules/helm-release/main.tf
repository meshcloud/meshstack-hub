resource "helm_release" "this" {
  lifecycle {
    enabled = !var.release_on_destroy
  }

  name       = var.name
  namespace  = var.namespace
  repository = var.repository
  chart      = var.chart
  version    = var.chart_version
  values     = var.values

  create_namespace = false
  take_ownership   = var.take_ownership
  atomic           = var.atomic
  wait             = true
  timeout          = var.timeout
}

resource "helm_release" "released" {
  lifecycle {
    enabled         = var.release_on_destroy
    destroy         = false
    prevent_destroy = true
  }

  name       = var.name
  namespace  = var.namespace
  repository = var.repository
  chart      = var.chart
  version    = var.chart_version
  values     = var.values

  create_namespace = false
  take_ownership   = var.take_ownership
  atomic           = var.atomic
  wait             = true
  timeout          = var.timeout
}

# Flipping the flag on existing state would replace the release.
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
