module "cluster" {
  source = "./modules/ske-cluster"

  release_on_destroy     = var.release_on_destroy
  project_id             = var.stackit_project_id
  region                 = var.stackit_region
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

moved {
  from = stackit_ske_cluster.this
  to   = module.cluster.stackit_ske_cluster.this
}

import {
  for_each = var.imports != null && !var.release_on_destroy ? toset([var.cluster_name]) : toset([])
  to       = module.cluster.stackit_ske_cluster.this
  id       = "${var.stackit_project_id},${var.stackit_region},${each.value}"
}

import {
  for_each = var.imports != null && var.release_on_destroy ? toset([var.cluster_name]) : toset([])
  to       = module.cluster.stackit_ske_cluster.released
  id       = "${var.stackit_project_id},${var.stackit_region},${each.value}"
}
