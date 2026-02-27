resource "stackit_ske_cluster" "this" {
  project_id = var.stackit_project_id
  name       = var.cluster_name
  node_pools = [
    {
      name               = "default"
      machine_type       = var.machine_type
      minimum            = var.node_count
      maximum            = var.node_count
      availability_zones = var.availability_zones
      volume_size        = var.volume_size
      volume_type        = var.volume_type
    }
  ]
  maintenance = {
    enable_kubernetes_version_updates    = var.enable_kubernetes_version_updates
    enable_machine_image_version_updates = var.enable_machine_image_version_updates
    start                                = var.maintenance_start
    end                                  = var.maintenance_end
  }

  lifecycle {
    ignore_changes = [kubernetes_version_used, node_pools[0].os_version_used]
  }
}

resource "stackit_ske_kubeconfig" "this" {
  project_id   = var.stackit_project_id
  cluster_name = stackit_ske_cluster.this.name
  expiration   = "15552000" # 180 days
  refresh      = true
}

locals {
  kubeconfig             = yamldecode(stackit_ske_kubeconfig.this.kube_config)
  kube_host              = local.kubeconfig["clusters"][0]["cluster"]["server"]
  cluster_ca_certificate = base64decode(local.kubeconfig["clusters"][0]["cluster"]["certificate-authority-data"])
  client_certificate     = base64decode(local.kubeconfig["users"][0]["user"]["client-certificate-data"])
  client_key             = base64decode(local.kubeconfig["users"][0]["user"]["client-key-data"])
}

provider "kubernetes" {
  host                   = local.kube_host
  cluster_ca_certificate = local.cluster_ca_certificate
  client_certificate     = local.client_certificate
  client_key             = local.client_key
}

module "meshplatform" {
  source = "git::https://github.com/meshcloud/terraform-kubernetes-meshplatform.git?ref=v0.1.0"

  namespace          = var.meshplatform_namespace
  replicator_enabled = true
  metering_enabled   = true
}
