resource "stackit_ske_cluster" "this" {
  project_id = var.stackit_project_id
  name       = var.cluster_name

  node_pools = var.node_pools

  maintenance = {
    enable_kubernetes_version_updates    = var.maintenance.enable_kubernetes_version_updates
    enable_machine_image_version_updates = var.maintenance.enable_machine_image_version_updates
    start                                = var.maintenance.start
    end                                  = var.maintenance.end
  }

  network    = local.network
  extensions = local.extensions
}

resource "stackit_ske_kubeconfig" "this" {
  project_id   = var.stackit_project_id
  cluster_name = stackit_ske_cluster.this.name
  expiration   = var.kubeconfig_expiration_seconds
  refresh      = true
}

locals {
  # `network` stays unset unless the caller asks for something, because SKE rejects a
  # `control_plane` block from accounts that are not enabled for the feature.
  network = var.network_id == null && var.control_plane_access_scope == null ? null : {
    id = var.network_id
    control_plane = var.control_plane_access_scope == null ? null : {
      access_scope = var.control_plane_access_scope
    }
  }

  extensions = var.dns_extension == null ? null : {
    dns = {
      enabled     = var.dns_extension.enabled
      zones       = var.dns_extension.zones
      gateway_api = var.dns_extension.gateway_api
    }
  }

  kubeconfig            = yamldecode(stackit_ske_kubeconfig.this.kube_config)
  kubeconfig_cluster    = one(local.kubeconfig.clusters).cluster
  kubeconfig_admin_user = one(local.kubeconfig.users).user
}
