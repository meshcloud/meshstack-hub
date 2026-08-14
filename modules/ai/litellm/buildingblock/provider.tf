provider "kubernetes" {
  host                   = "https://${var.cluster_endpoint}"
  cluster_ca_certificate = base64decode(var.cluster_ca_certificate)

  # A service account token is the usual credential. The certificate pair is accepted as well, so a
  # kubeconfig produced by a managed cluster's own credential API also works. Exactly one of the two
  # is set; the unused attributes stay null and the provider ignores them.
  token              = var.token
  client_certificate = var.client_certificate
  client_key         = var.client_key
}

# The helm provider talks to the same control plane with the same credentials, so the namespace,
# the secrets and the Helm release all land in one cluster without extra wiring.
provider "helm" {
  kubernetes = {
    host                   = "https://${var.cluster_endpoint}"
    cluster_ca_certificate = base64decode(var.cluster_ca_certificate)

    token              = var.token
    client_certificate = var.client_certificate
    client_key         = var.client_key
  }
}
