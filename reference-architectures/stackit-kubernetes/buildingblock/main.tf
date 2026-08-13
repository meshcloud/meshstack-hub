module "cluster" {
  source = "github.com/meshcloud/meshstack-hub//modules/stackit/ske/buildingblock?ref=${var.hub.git_ref}"

  stackit_project_id    = var.stackit_project_id
  stackit_region        = var.stackit_region
  service_account_email = var.stackit_service_account_email
  cluster_name          = var.cluster_name

  # The whole DNS design lives in dns.tf.
  dns_extension = local.ske_dns_extension
}

# Registers the cluster as a meshStack platform whose tenants are namespaces, together with the
# dev and prod namespace landing zones the module brings by default. The platform name equals the
# cluster name, so several ordered clusters can coexist in one meshStack instance.
module "platform" {
  source = "github.com/meshcloud/meshstack-hub//modules/kubernetes/platform/buildingblock?ref=${var.hub.git_ref}"

  kube_host              = module.cluster.kube_host
  cluster_ca_certificate = module.cluster.provider_config.cluster_ca_certificate
  client_certificate     = module.cluster.provider_config.client_certificate
  client_key             = module.cluster.provider_config.client_key

  owning_workspace_identifier = var.owning_workspace_identifier
  location_identifier         = var.location_identifier

  platform_name         = var.cluster_name
  platform_display_name = "Kubernetes namespace on ${var.cluster_name}"
  platform_description  = "Provides a Kubernetes namespace on the STACKIT Kubernetes Engine cluster ${var.cluster_name}, with a shared HTTPS ingress."
}

# cert-manager, the HAProxy ingress controller and the Let's Encrypt ClusterIssuer. With DNS on,
# the module also issues one wildcard certificate for the cluster's own domain inside the shared
# zone, which HAProxy serves for every application hostname.
module "ingress" {
  count  = var.expose == "none" ? 0 : 1
  source = "github.com/meshcloud/meshstack-hub//modules/kubernetes/ingress/buildingblock?ref=${var.hub.git_ref}"

  providers = {
    kubernetes = kubernetes
    helm       = helm
  }

  acme_email          = var.acme_email
  acme_server         = var.acme_server
  cluster_issuer_name = var.cluster_issuer_name
  ingress_class_name  = var.ingress_class_name

  # STACKIT reads this annotation on the controller Service and keeps the load balancer off the
  # public internet.
  haproxy_service_annotations = var.expose == "internal" ? { "lb.stackit.cloud/internal-lb" = "true" } : {}

  dns01 = local.ingress_dns01
}
