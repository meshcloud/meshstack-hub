# Targets the SKE cluster whose kubeconfig arrives as var.kubeconfig. The config reads from a variable
# (not a resource created here), so it is known at plan time — which lets kubernetes_manifest look up
# the ClusterIssuer CRD that the preceding platform-services building block already installed.
provider "kubernetes" {
  host                   = local.kube.host
  cluster_ca_certificate = local.kube.cluster_ca_certificate
  client_certificate     = local.kube.client_certificate
  client_key             = local.kube.client_key
}
