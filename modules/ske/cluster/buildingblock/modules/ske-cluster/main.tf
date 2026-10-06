resource "stackit_ske_cluster" "this" {
  lifecycle {
    enabled = !var.release_on_destroy
  }

  project_id             = var.project_id
  region                 = var.region
  name                   = var.name
  kubernetes_version_min = var.kubernetes_version_min
  node_pools             = var.node_pools
  maintenance            = var.maintenance
}

resource "stackit_ske_cluster" "released" {
  lifecycle {
    enabled         = var.release_on_destroy
    destroy         = false
    prevent_destroy = true
  }

  project_id             = var.project_id
  region                 = var.region
  name                   = var.name
  kubernetes_version_min = var.kubernetes_version_min
  node_pools             = var.node_pools
  maintenance            = var.maintenance
}

# Flipping the flag on existing state would replace the cluster.
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
