locals {
  kubeconfig_cluster = one(yamldecode(var.kubeconfig)["clusters"])["cluster"]
  kubeconfig_user    = one(yamldecode(var.kubeconfig)["users"])["user"]
}

# The kubeconfig comes from the parent Kubernetes Service Account building block, which issues a
# service account token.
provider "kubernetes" {
  host                   = local.kubeconfig_cluster["server"]
  cluster_ca_certificate = base64decode(local.kubeconfig_cluster["certificate-authority-data"])
  token                  = local.kubeconfig_user["token"]
}
