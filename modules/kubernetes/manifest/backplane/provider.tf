locals {
  kubeconfig_cluster      = one(var.kubeconfig_admin["clusters"])["cluster"]
  kubeconfig_cluster_name = one(var.kubeconfig_admin["clusters"])["name"]
  kubeconfig_admin_user   = one(var.kubeconfig_admin["users"])["user"]
}

provider "kubernetes" {
  host                   = local.kubeconfig_cluster["server"]
  cluster_ca_certificate = base64decode(local.kubeconfig_cluster["certificate-authority-data"])
  client_certificate     = base64decode(local.kubeconfig_admin_user["client-certificate-data"])
  client_key             = base64decode(local.kubeconfig_admin_user["client-key-data"])
}
