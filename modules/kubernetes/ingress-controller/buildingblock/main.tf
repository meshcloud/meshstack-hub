locals {
  # The chart derives the controller Service name from the release name.
  haproxy_service_name = "${var.haproxy_release_name}-kubernetes-ingress"

  issuer_release_name = "ingress-issuer"

  # The API server rejects a null resource quantity.
  resources = {
    for name, spec in {
      cert_manager                 = var.cert_manager_resources
      cert_manager_webhook         = var.cert_manager_webhook_resources
      cert_manager_cainjector      = var.cert_manager_cainjector_resources
      cert_manager_startupapicheck = var.cert_manager_startupapicheck_resources
      haproxy                      = var.haproxy_resources
      haproxy_crdjob               = var.haproxy_crdjob_resources
      } : name => {
      requests = { for key, value in spec.requests : key => value if value != null }
      limits   = { for key, value in spec.limits : key => value if value != null }
    }
  }
}

resource "terraform_data" "kubeconfig" {
  lifecycle {
    precondition {
      condition     = fileexists("${path.module}/kubeconfig.yaml")
      error_message = "kubeconfig.yaml is missing. meshStack writes it from the FILE input of the building block."
    }
  }
}

module "cert_manager_namespace" {
  source = "./modules/namespace"

  depends_on = [terraform_data.kubeconfig]

  release_on_destroy = var.release_on_destroy
  name               = var.cert_manager_namespace
}

module "cert_manager" {
  source = "./modules/helm-release"

  release_on_destroy = var.release_on_destroy
  name               = "cert-manager"
  namespace          = module.cert_manager_namespace.name
  repository         = "https://charts.jetstack.io"
  chart              = "cert-manager"
  chart_version      = var.cert_manager_version
  timeout            = 300

  values = [
    yamlencode({
      crds = {
        enabled = true
        keep    = var.cert_manager_crds_keep
      }
      extraArgs = var.cert_manager_extra_args

      # The chart ships no resources for any of its four workloads.
      resources       = local.resources.cert_manager
      webhook         = { resources = local.resources.cert_manager_webhook }
      cainjector      = { resources = local.resources.cert_manager_cainjector }
      startupapicheck = { resources = local.resources.cert_manager_startupapicheck }
    })
  ]
}

module "haproxy_namespace" {
  source = "./modules/namespace"

  depends_on = [terraform_data.kubeconfig]

  release_on_destroy = var.release_on_destroy
  name               = var.haproxy_namespace
}

# Helm applies the cert-manager resources without the plan-time CRD lookup of kubernetes_manifest.
module "issuer" {
  source = "./modules/helm-release"

  release_on_destroy = var.release_on_destroy
  name               = local.issuer_release_name
  namespace          = module.cert_manager_namespace.name
  chart              = "${path.module}/chart"
  take_ownership     = var.imports != null
  # A failed atomic install would uninstall the adopted ClusterIssuer.
  atomic  = var.imports == null
  timeout = 300

  values = [
    yamlencode({
      clusterIssuer = {
        name                 = var.cluster_issuer_name
        email                = var.acme_email
        server               = var.acme_server
        privateKeySecretName = var.acme_private_key_secret_name
      }
      ingressClassName = var.ingress_class_name
    })
  ]

  depends_on = [module.cert_manager]
}

module "haproxy" {
  source = "./modules/helm-release"

  release_on_destroy = var.release_on_destroy
  name               = var.haproxy_release_name
  namespace          = module.haproxy_namespace.name
  repository         = "https://haproxytech.github.io/helm-charts"
  chart              = "kubernetes-ingress"
  chart_version      = var.haproxy_version
  timeout            = var.haproxy_timeout

  values = [
    yamlencode({
      crdjob = { resources = local.resources.haproxy_crdjob }

      controller = {
        replicaCount         = var.haproxy_replica_count
        ingressClass         = var.ingress_class_name
        ingressClassResource = { name = var.ingress_class_name }
        resources            = local.resources.haproxy
        service = {
          type        = var.haproxy_service_type
          annotations = var.haproxy_service_annotations
        }
      }
    })
  ]

  depends_on = [module.issuer]
}

data "kubernetes_service_v1" "haproxy_controller" {
  metadata {
    name      = local.haproxy_service_name
    namespace = module.haproxy_namespace.name
  }

  depends_on = [module.haproxy]
}

import {
  for_each = var.imports != null && !var.release_on_destroy ? toset([var.cert_manager_namespace]) : toset([])
  to       = module.cert_manager_namespace.kubernetes_namespace_v1.this
  id       = each.value
}

import {
  for_each = var.imports != null && var.release_on_destroy ? toset([var.cert_manager_namespace]) : toset([])
  to       = module.cert_manager_namespace.kubernetes_namespace_v1.released
  id       = each.value
}

import {
  for_each = var.imports != null && !var.release_on_destroy ? toset([var.haproxy_namespace]) : toset([])
  to       = module.haproxy_namespace.kubernetes_namespace_v1.this
  id       = each.value
}

import {
  for_each = var.imports != null && var.release_on_destroy ? toset([var.haproxy_namespace]) : toset([])
  to       = module.haproxy_namespace.kubernetes_namespace_v1.released
  id       = each.value
}

import {
  for_each = var.imports != null && !var.release_on_destroy ? toset(["${var.cert_manager_namespace}/cert-manager"]) : toset([])
  to       = module.cert_manager.helm_release.this
  id       = each.value
}

import {
  for_each = var.imports != null && var.release_on_destroy ? toset(["${var.cert_manager_namespace}/cert-manager"]) : toset([])
  to       = module.cert_manager.helm_release.released
  id       = each.value
}

import {
  for_each = var.imports != null && !var.release_on_destroy ? toset(["${var.haproxy_namespace}/${var.haproxy_release_name}"]) : toset([])
  to       = module.haproxy.helm_release.this
  id       = each.value
}

import {
  for_each = var.imports != null && var.release_on_destroy ? toset(["${var.haproxy_namespace}/${var.haproxy_release_name}"]) : toset([])
  to       = module.haproxy.helm_release.released
  id       = each.value
}

moved {
  from = module.ingress.kubernetes_namespace_v1.cert_manager
  to   = kubernetes_namespace_v1.cert_manager
}

moved {
  from = kubernetes_namespace_v1.cert_manager
  to   = module.cert_manager_namespace.kubernetes_namespace_v1.this
}

moved {
  from = module.ingress.helm_release.cert_manager
  to   = helm_release.cert_manager
}

moved {
  from = helm_release.cert_manager
  to   = module.cert_manager.helm_release.this
}

moved {
  from = module.ingress.kubernetes_namespace_v1.haproxy_ingress
  to   = kubernetes_namespace_v1.haproxy_ingress
}

moved {
  from = kubernetes_namespace_v1.haproxy_ingress
  to   = module.haproxy_namespace.kubernetes_namespace_v1.this
}

moved {
  from = module.ingress.helm_release.issuer
  to   = helm_release.issuer
}

moved {
  from = helm_release.issuer
  to   = module.issuer.helm_release.this
}

moved {
  from = module.ingress.helm_release.haproxy
  to   = helm_release.haproxy
}

moved {
  from = helm_release.haproxy
  to   = module.haproxy.helm_release.this
}
