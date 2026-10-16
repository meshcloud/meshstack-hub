locals {
  # lifecycle.enabled, names and outputs reject a sensitive value, so the plain facts of var.dns01
  # are unmarked while its credentials keep the mark.
  # try: nonsensitive() rejects a value without the mark, which is the case when var.dns01 is null.
  dns01_enabled = try(nonsensitive(var.dns01 != null), var.dns01 != null)
  # try: as above.
  dns01_stackit_enabled = local.dns01_enabled ? try(nonsensitive(var.dns01.stackit != null), var.dns01.stackit != null) : false
  # try: as above.
  dns01_route53_enabled = local.dns01_enabled ? try(nonsensitive(var.dns01.route53 != null), var.dns01.route53 != null) : false
  # try: as above.
  dns01_zone_name = local.dns01_enabled ? try(nonsensitive(var.dns01.zone_name), var.dns01.zone_name) : null
  # try: as above.
  dns01_certificate_domain = local.dns01_enabled ? coalesce(
    try(nonsensitive(var.dns01.certificate_domain), var.dns01.certificate_domain),
    local.dns01_zone_name
  ) : null

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
      stackit_webhook              = var.stackit_webhook_resources
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
      error_message = "kubeconfig.yaml is missing. meshStack writes it from the static FILE input of the building block definition."
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

# The webhook mounts the key from a secret in its own namespace.
resource "kubernetes_secret_v1" "stackit_dns01" {
  lifecycle {
    enabled = local.dns01_stackit_enabled
  }

  metadata {
    name      = "stackit-sa-authentication"
    namespace = module.cert_manager_namespace.name
  }

  data = {
    "sa.json" = var.dns01.stackit.service_account_key
  }
}

# cert-manager has no built-in solver for STACKIT DNS.
resource "helm_release" "stackit_cert_manager_webhook" {
  lifecycle {
    enabled = local.dns01_stackit_enabled
  }

  name       = "stackit-cert-manager-webhook"
  namespace  = module.cert_manager_namespace.name
  repository = "https://stackitcloud.github.io/stackit-cert-manager-webhook"
  chart      = "stackit-cert-manager-webhook"
  version    = var.stackit_webhook_version

  create_namespace = false
  wait             = true
  timeout          = 300

  values = [
    yamlencode({
      groupName = "acme.stackit.de"
      certManager = {
        namespace          = module.cert_manager_namespace.name
        serviceAccountName = "cert-manager"
      }
      stackitSaAuthentication = {
        enabled    = true
        secretName = kubernetes_secret_v1.stackit_dns01.metadata[0].name
      }
      resources = local.resources.stackit_webhook
    })
  ]

  depends_on = [module.cert_manager]
}

resource "kubernetes_secret_v1" "route53_dns01" {
  lifecycle {
    enabled = local.dns01_route53_enabled
  }

  metadata {
    name      = "route53-dns01-credentials"
    namespace = module.cert_manager_namespace.name
  }

  data = {
    "secret-access-key" = var.dns01.route53.secret_access_key
  }
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
      dns01 = {
        zoneName = local.dns01_zone_name
        stackit = local.dns01_stackit_enabled ? {
          projectId = var.dns01.stackit.project_id
        } : null
        route53 = local.dns01_route53_enabled ? {
          region                    = var.dns01.route53.region
          hostedZoneID              = var.dns01.route53.hosted_zone_id
          accessKeyID               = var.dns01.route53.access_key_id
          secretAccessKeySecretName = kubernetes_secret_v1.route53_dns01.metadata[0].name
          secretAccessKeySecretKey  = "secret-access-key"
        } : null
      }
      wildcardCertificate = {
        enabled    = local.dns01_enabled
        domain     = local.dns01_certificate_domain
        name       = var.wildcard_certificate_name
        namespace  = module.haproxy_namespace.name
        secretName = var.wildcard_certificate_name
      }
    })
  ]

  depends_on = [
    module.cert_manager,
    helm_release.stackit_cert_manager_webhook,
  ]
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

      controller = merge(
        {
          replicaCount         = var.haproxy_replica_count
          ingressClass         = var.ingress_class_name
          ingressClassResource = { name = var.ingress_class_name }
          resources            = local.resources.haproxy
          service = {
            type        = var.haproxy_service_type
            annotations = var.haproxy_service_annotations
          }
        },
        # defaultTLSSecret.secretNamespace defaults to the release namespace, where the wildcard
        # Certificate writes its secret.
        local.dns01_enabled ? { defaultTLSSecret = { secret = var.wildcard_certificate_name } } : {}
      )
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
  from = kubernetes_secret_v1.stackit_dns01[0]
  to   = kubernetes_secret_v1.stackit_dns01
}

moved {
  from = helm_release.stackit_cert_manager_webhook[0]
  to   = helm_release.stackit_cert_manager_webhook
}

moved {
  from = kubernetes_secret_v1.route53_dns01[0]
  to   = kubernetes_secret_v1.route53_dns01
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
  from = module.ingress.kubernetes_secret_v1.stackit_dns01
  to   = kubernetes_secret_v1.stackit_dns01
}

moved {
  from = module.ingress.helm_release.stackit_cert_manager_webhook
  to   = helm_release.stackit_cert_manager_webhook
}

moved {
  from = module.ingress.kubernetes_secret_v1.route53_dns01
  to   = kubernetes_secret_v1.route53_dns01
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
