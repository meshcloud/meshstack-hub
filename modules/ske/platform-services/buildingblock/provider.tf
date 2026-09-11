# Both providers target the SKE cluster whose kubeconfig arrives as var.kubeconfig. They share the
# same credentials so namespaces, Helm releases and manifests all land on the same control plane.
# The config reads from a variable (not a resource created here), so it is known at plan time.
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
