provider "kubernetes" {
  host                   = local.kube.host
  cluster_ca_certificate = local.kube.cluster_ca_certificate
  client_certificate     = local.kube.client_certificate
  client_key             = local.kube.client_key
}

provider "helm" {
  kubernetes = {
    host                   = local.kube.host
    cluster_ca_certificate = local.kube.cluster_ca_certificate
    client_certificate     = local.kube.client_certificate
    client_key             = local.kube.client_key
  }
}
