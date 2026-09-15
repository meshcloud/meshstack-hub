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

# ── Ingress: HAProxy behind a STACKIT LoadBalancer ──

resource "kubernetes_namespace_v1" "haproxy_ingress" {
  metadata {
    name = "haproxy-ingress"
  }
}

resource "helm_release" "haproxy" {
  name       = "haproxy"
  namespace  = kubernetes_namespace_v1.haproxy_ingress.metadata[0].name
  repository = "https://haproxytech.github.io/helm-charts"
  chart      = "kubernetes-ingress"
  version    = var.haproxy_version

  create_namespace = false
  # 20 min should cover the NLB being provisioned and becoming ready.
  timeout = 20 * 60

  values = [yamlencode({
    controller = {
      replicaCount = var.haproxy_replica_count
      service = {
        type = "LoadBalancer"
      }
    }
  })]
}

# The LoadBalancer IP STACKIT assigns once HAProxy is up — a composition points DNS A records here.
data "kubernetes_service_v1" "haproxy_controller" {
  metadata {
    name      = "haproxy-kubernetes-ingress"
    namespace = kubernetes_namespace_v1.haproxy_ingress.metadata[0].name
  }

  depends_on = [helm_release.haproxy]
}

# ── cert-manager + Let's Encrypt ClusterIssuer ──

resource "kubernetes_namespace_v1" "cert_manager" {
  metadata {
    name = "cert-manager"
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

  values = [yamlencode({
    crds = {
      enabled = true
      keep    = false # remove CRDs on destroy
    }
    extraArgs = [
      # Recover quickly from transient ACME order failures (default backoff is 1h).
      "--certificate-request-minimum-backoff-duration=1m"
    ]
  })]
}

# Separate from the Helm release: the manifest needs the ClusterIssuer CRD that cert-manager installs
# first. HTTP-01 solves challenges through the HAProxy ingress class.
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
              ingressClassName = "haproxy"
            }
          }
        }]
      }
    }
  }

  depends_on = [helm_release.cert_manager]
}

# ── meshStack replication + metering service accounts ──
# Creates the in-cluster service accounts and tokens meshStack uses to replicate namespaces and read
# metering data. The parent architecture feeds these tokens into the meshstack_platform resource.
module "meshplatform" {
  source = "git::https://github.com/meshcloud/terraform-kubernetes-meshplatform.git?ref=v0.2.0"

  replicator_enabled = true
  metering_enabled   = true
}
