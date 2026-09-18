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

# The Let's Encrypt ClusterIssuer is NOT created here: it is a cert-manager custom resource, and
# kubernetes_manifest validates its CRD at plan time — which cannot work in the same run that installs
# cert-manager. It lives in the separate `ske/cluster-issuer` building block, ordered after this one.

# ── meshStack replication + metering service accounts ──
# Creates the in-cluster service accounts and tokens meshStack uses to replicate namespaces and read
# metering data. The parent architecture feeds these tokens into the meshstack_platform resource.
module "meshplatform" {
  source = "git::https://github.com/meshcloud/terraform-kubernetes-meshplatform.git?ref=v0.2.0"

  replicator_enabled = true
  metering_enabled   = true
}

# Kubernetes populates a `kubernetes.io/service-account-token` secret's `data.token` field
# ASYNCHRONOUSLY after the secret is created, so the meshplatform module reads it empty on the creating
# apply — which is how meshStack ends up with a blank token and replication/metering get 401
# Unauthorized. A fixed sleep is only a guess at the propagation delay. Instead each data source below
# carries a postcondition that fails while its token is still empty, and the BBD's pre_run_script (see
# meshstack_integration.tf) polls these data sources (`tofu apply -target`) until both postconditions
# pass — so by the time the main apply reads them the tokens are guaranteed present, and a blank token
# can never reach meshStack. Secret names/namespace are the meshplatform module's fixed defaults for our
# usage (no name_suffix; namespace "meshcloud").
data "kubernetes_secret" "replicator" {
  metadata {
    name      = "meshfed-service"
    namespace = "meshcloud"
  }
  depends_on = [module.meshplatform]

  lifecycle {
    postcondition {
      condition     = self.data["token"] != ""
      error_message = "Kubernetes has not populated the meshfed-service service-account-token yet."
    }
  }
}

data "kubernetes_secret" "metering" {
  metadata {
    name      = "meshfed-metering"
    namespace = "meshcloud"
  }
  depends_on = [module.meshplatform]

  lifecycle {
    postcondition {
      condition     = self.data["token"] != ""
      error_message = "Kubernetes has not populated the meshfed-metering service-account-token yet."
    }
  }
}
