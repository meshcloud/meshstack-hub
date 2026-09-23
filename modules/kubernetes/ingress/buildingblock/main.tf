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

# A composition that already holds cluster credentials sources `./ingress` directly instead: a
# caller can neither override a provider its child module configures nor put `count` or
# `depends_on` on such a module. Every knob meshStack does not send keeps the submodule's default,
# and DNS-01 stays off because it needs a long-lived zone credential in the cluster.
module "ingress" {
  source = "./ingress"

  cert_manager_version = var.cert_manager_version

  haproxy_version             = var.haproxy_version
  haproxy_replica_count       = var.haproxy_replica_count
  haproxy_service_annotations = var.haproxy_service_annotations
  ingress_class_name          = var.ingress_class_name

  acme_email          = var.acme_email
  acme_server         = var.acme_server
  cluster_issuer_name = var.cluster_issuer_name
}
