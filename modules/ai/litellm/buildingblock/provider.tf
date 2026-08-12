provider "kubernetes" {
  host                   = "https://${var.cluster_endpoint}"
  cluster_ca_certificate = base64decode(var.cluster_ca_certificate)
  token                  = var.token
}

# The helm provider talks to the same control plane with the same credentials, so the namespace,
# the secrets and the Helm release all land in one cluster without extra wiring.
provider "helm" {
  kubernetes = {
    host                   = "https://${var.cluster_endpoint}"
    cluster_ca_certificate = base64decode(var.cluster_ca_certificate)
    token                  = var.token
  }
}
