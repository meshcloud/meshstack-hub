locals {
  # var.dns01 is sensitive as a whole, so every expression derived from it carries the sensitivity
  # mark. count arguments, resource names and outputs reject a marked value, so unmark the plain
  # facts — is DNS-01 on, which provider, which zone — while the credentials keep their mark.
  # nonsensitive() rejects an argument that carries no mark, so try() falls back to the value.
  dns01_enabled         = try(nonsensitive(var.dns01 != null), var.dns01 != null)
  dns01_stackit_enabled = local.dns01_enabled ? try(nonsensitive(var.dns01.stackit != null), var.dns01.stackit != null) : false
  dns01_route53_enabled = local.dns01_enabled ? try(nonsensitive(var.dns01.route53 != null), var.dns01.route53 != null) : false
  dns01_zone_name       = local.dns01_enabled ? try(nonsensitive(var.dns01.zone_name), var.dns01.zone_name) : null

  # The solver answers for the whole zone, while the certificate may cover a narrower domain
  # inside it. A caller that sets no certificate_domain gets the zone itself, which is the
  # wildcard `*.<zone_name>`.
  dns01_certificate_domain = local.dns01_enabled ? coalesce(
    try(nonsensitive(var.dns01.certificate_domain), var.dns01.certificate_domain),
    local.dns01_zone_name
  ) : null

  # The chart derives the controller Service name from the release name.
  haproxy_service_name = "${var.haproxy_release_name}-kubernetes-ingress"

  # Helm renders these values into the pod spec as YAML, and the API server rejects a resource
  # quantity that is null, so drop every field the caller left unset.
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

resource "kubernetes_namespace_v1" "cert_manager" {
  metadata {
    name = var.cert_manager_namespace
  }
}

resource "helm_release" "cert_manager" {
  name       = "cert-manager"
  namespace  = kubernetes_namespace_v1.cert_manager.metadata[0].name
  repository = "https://charts.jetstack.io"
  chart      = "cert-manager"
  version    = var.cert_manager_version

  create_namespace = false
  wait             = true
  timeout          = 300

  values = [
    yamlencode({
      crds = {
        enabled = true
        keep    = var.cert_manager_crds_keep
      }
      extraArgs = var.cert_manager_extra_args

      # The chart ships no resources for any of its four workloads, so each of them would run
      # unbounded without these values.
      resources       = local.resources.cert_manager
      webhook         = { resources = local.resources.cert_manager_webhook }
      cainjector      = { resources = local.resources.cert_manager_cainjector }
      startupapicheck = { resources = local.resources.cert_manager_startupapicheck }
    })
  ]
}

# The webhook mounts the STACKIT service account key from a secret, so the secret has to sit in
# the same namespace as the webhook pod.
resource "kubernetes_secret_v1" "stackit_dns01" {
  count = local.dns01_stackit_enabled ? 1 : 0

  metadata {
    name      = "stackit-sa-authentication"
    namespace = kubernetes_namespace_v1.cert_manager.metadata[0].name
  }

  data = {
    "sa.json" = var.dns01.stackit.service_account_key
  }
}

# cert-manager has no built-in solver for STACKIT DNS. This chart registers one under the
# acme.stackit.de API group, which the ClusterIssuer then calls as solverName "stackit".
resource "helm_release" "stackit_cert_manager_webhook" {
  count = local.dns01_stackit_enabled ? 1 : 0

  name       = "stackit-cert-manager-webhook"
  namespace  = kubernetes_namespace_v1.cert_manager.metadata[0].name
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
        namespace          = kubernetes_namespace_v1.cert_manager.metadata[0].name
        serviceAccountName = "cert-manager"
      }
      stackitSaAuthentication = {
        enabled    = true
        secretName = kubernetes_secret_v1.stackit_dns01[0].metadata[0].name
      }
      resources = local.resources.stackit_webhook
    })
  ]

  depends_on = [helm_release.cert_manager]
}

# The route53 solver is built into cert-manager, so it needs no extra chart. It only needs the
# secret access key handed to it through a secret reference.
resource "kubernetes_secret_v1" "route53_dns01" {
  count = local.dns01_route53_enabled ? 1 : 0

  metadata {
    name      = "route53-dns01-credentials"
    namespace = kubernetes_namespace_v1.cert_manager.metadata[0].name
  }

  data = {
    "secret-access-key" = var.dns01.route53.secret_access_key
  }
}

resource "kubernetes_namespace_v1" "haproxy_ingress" {
  metadata {
    name = var.haproxy_namespace
  }
}

# The ClusterIssuer and the wildcard Certificate are custom resources whose CRDs only exist once
# cert-manager is installed. Helm renders and applies them without a plan-time schema lookup,
# which is what kubernetes_manifest would need — that lookup is the reason foundations had to run
# the ClusterIssuer as a separate Terraform unit.
resource "helm_release" "issuer" {
  name      = "ingress-issuer"
  namespace = kubernetes_namespace_v1.cert_manager.metadata[0].name
  chart     = path.module

  atomic  = true
  wait    = true
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
          secretAccessKeySecretName = kubernetes_secret_v1.route53_dns01[0].metadata[0].name
          secretAccessKeySecretKey  = "secret-access-key"
        } : null
      }
      wildcardCertificate = {
        enabled    = local.dns01_enabled
        domain     = local.dns01_certificate_domain
        name       = var.wildcard_certificate_name
        namespace  = kubernetes_namespace_v1.haproxy_ingress.metadata[0].name
        secretName = var.wildcard_certificate_name
      }
    })
  ]

  depends_on = [
    helm_release.cert_manager,
    helm_release.stackit_cert_manager_webhook
  ]
}

resource "helm_release" "haproxy" {
  name       = var.haproxy_release_name
  namespace  = kubernetes_namespace_v1.haproxy_ingress.metadata[0].name
  repository = "https://haproxytech.github.io/helm-charts"
  chart      = "kubernetes-ingress"
  version    = var.haproxy_version

  create_namespace = false
  timeout          = var.haproxy_timeout

  values = [
    yamlencode({
      # The chart requests 250m CPU and 400Mi memory for the controller and for the CRD Job, and
      # sets no limit on either.
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
        # HAProxy serves this certificate for every host that brings no certificate of its own.
        # controller.defaultTLSSecret.secretNamespace defaults to the release namespace, which is
        # where the wildcard Certificate writes its secret, so only the name has to be set.
        # Without DNS-01 the chart default stays in place and HAProxy keeps its self-signed
        # certificate for unmatched hosts.
        local.dns01_enabled ? { defaultTLSSecret = { secret = var.wildcard_certificate_name } } : {}
      )
    })
  ]

  depends_on = [helm_release.issuer]
}

# The cloud provider assigns the load balancer address after HAProxy is up. Foundations point
# their DNS A records at it.
data "kubernetes_service_v1" "haproxy_controller" {
  metadata {
    name      = local.haproxy_service_name
    namespace = kubernetes_namespace_v1.haproxy_ingress.metadata[0].name
  }

  depends_on = [helm_release.haproxy]
}
