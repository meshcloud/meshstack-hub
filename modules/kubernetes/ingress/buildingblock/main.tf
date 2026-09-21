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

# cert-manager, the HAProxy ingress controller, the ClusterIssuer and the optional wildcard
# certificate all live in `./ingress`, a module that declares no provider configuration. This root
# supplies the two providers that module needs and is what meshStack runs when the building block
# is ordered.
#
# A composition that already holds cluster credentials sources `./ingress` directly instead. It has
# to: a caller cannot override a provider its child module configures, and it cannot put `count` or
# `depends_on` on a module that carries one either — which a composition installing ingress
# conditionally, or after something else, needs.
module "ingress" {
  source = "./ingress"

  cert_manager_version                   = var.cert_manager_version
  cert_manager_namespace                 = var.cert_manager_namespace
  cert_manager_extra_args                = var.cert_manager_extra_args
  cert_manager_crds_keep                 = var.cert_manager_crds_keep
  cert_manager_resources                 = var.cert_manager_resources
  cert_manager_webhook_resources         = var.cert_manager_webhook_resources
  cert_manager_cainjector_resources      = var.cert_manager_cainjector_resources
  cert_manager_startupapicheck_resources = var.cert_manager_startupapicheck_resources

  haproxy_version             = var.haproxy_version
  haproxy_namespace           = var.haproxy_namespace
  haproxy_release_name        = var.haproxy_release_name
  haproxy_replica_count       = var.haproxy_replica_count
  haproxy_resources           = var.haproxy_resources
  haproxy_crdjob_resources    = var.haproxy_crdjob_resources
  haproxy_service_type        = var.haproxy_service_type
  haproxy_service_annotations = var.haproxy_service_annotations
  haproxy_timeout             = var.haproxy_timeout
  ingress_class_name          = var.ingress_class_name

  acme_email                   = var.acme_email
  acme_server                  = var.acme_server
  cluster_issuer_name          = var.cluster_issuer_name
  acme_private_key_secret_name = var.acme_private_key_secret_name

  wildcard_certificate_name = var.wildcard_certificate_name
  stackit_webhook_version   = var.stackit_webhook_version
  stackit_webhook_resources = var.stackit_webhook_resources
  dns01                     = var.dns01
}
