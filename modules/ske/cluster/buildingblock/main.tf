resource "stackit_ske_cluster" "this" {
  project_id             = var.stackit_project_id
  name                   = var.cluster_name
  kubernetes_version_min = var.kubernetes_version_min

  node_pools = [
    {
      name               = var.node_pool.name
      machine_type       = var.node_pool.machine_type
      minimum            = var.node_pool.minimum
      maximum            = var.node_pool.maximum
      availability_zones = var.node_pool.availability_zones
      max_surge          = var.node_pool.max_surge
    }
  ]

  maintenance = {
    enable_kubernetes_version_updates    = var.maintenance.enable_kubernetes_version_updates
    enable_machine_image_version_updates = var.maintenance.enable_machine_image_version_updates
    start                                = var.maintenance.start
    end                                  = var.maintenance.end
  }
}

resource "stackit_ske_kubeconfig" "this" {
  project_id   = var.stackit_project_id
  cluster_name = stackit_ske_cluster.this.name

  # 180 days is the maximum the SKE API accepts; it rejects anything outside [600, 15552000] with a
  # 400. refresh = true re-mints the kubeconfig once it expires, but only when this module is applied.
  expiration = "15552000"
  refresh    = true
}

locals {
  kubeconfig            = yamldecode(stackit_ske_kubeconfig.this.kube_config)
  kubeconfig_cluster    = one(local.kubeconfig.clusters).cluster
  kubeconfig_admin_user = one(local.kubeconfig.users).user
}
