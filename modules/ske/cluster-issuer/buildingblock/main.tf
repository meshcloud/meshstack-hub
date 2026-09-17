locals {
  kubeconfig   = yamldecode(var.kubeconfig)
  kube_cluster = one(local.kubeconfig.clusters).cluster
  kube_user    = one(local.kubeconfig.users).user
  kube = {
    host                   = local.kube_cluster.server
    cluster_ca_certificate = base64decode(local.kube_cluster["certificate-authority-data"])
    client_certificate     = base64decode(local.kube_user["client-certificate-data"])
    client_key             = base64decode(local.kube_user["client-key-data"])
  }
}

# This lives in its own building block, separate from cert-manager, on purpose: a kubernetes_manifest
# resource validates its CRD's GroupVersionKind against the cluster at PLAN time. cert-manager installs
# the cert-manager.io CRDs, so the ClusterIssuer can only be planned once those CRDs already exist —
# which they do here, because platform-services (which installs cert-manager) runs in an earlier apply.
# HTTP-01 solves ACME challenges through the ingress class.
resource "kubernetes_manifest" "clusterissuer_letsencrypt_prod" {
  manifest = {
    apiVersion = "cert-manager.io/v1"
    kind       = "ClusterIssuer"
    metadata = {
      name = "letsencrypt-prod"
    }
    spec = {
      acme = {
        email  = var.cluster_issuer_email
        server = "https://acme-v02.api.letsencrypt.org/directory"
        privateKeySecretRef = {
          name = "letsencrypt-prod-account-key"
        }
        solvers = [{
          http01 = {
            ingress = {
              ingressClassName = var.ingress_class_name
            }
          }
        }]
      }
    }
  }
}
