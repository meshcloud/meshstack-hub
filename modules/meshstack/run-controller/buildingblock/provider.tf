provider "kubernetes" {
  host                   = var.kubernetes_api.server
  cluster_ca_certificate = var.kubernetes_api.cluster_ca_certificate
  token                  = var.kubernetes_api.token
}

provider "meshstack" {}
