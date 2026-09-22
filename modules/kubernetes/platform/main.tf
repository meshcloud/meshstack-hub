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

# In-cluster identities meshStack authenticates with.
#
# The replicator creates namespaces, resource quotas and role bindings for every tenant. The
# metering service account reads pods and persistent volume claims to collect usage data. Both are
# plain Kubernetes service accounts with a long-lived token, so no cloud identity provider is
# involved and this works on any conformant cluster.
#
# The names below are cluster-global: `meshfed-service` and `meshfed-metering` are ClusterRoles, and
# two of these deployed to one cluster would collide. That is fine here — each platform ordered from
# the STACKIT Kubernetes Platform reference architecture gets a cluster of its own — and it is why
# the upstream module's `name_suffix` / `existing_clusterrole_name` machinery is not carried over.
# Reintroduce it if a cluster ever has to carry more than one meshStack platform registration.

resource "kubernetes_namespace_v1" "meshcloud" {
  metadata {
    name = var.service_account_namespace
  }
}

# ── Replicator ──────────────────────────────────────────────────────────────

resource "kubernetes_service_account_v1" "replicator" {
  metadata {
    name      = local.replicator_name
    namespace = kubernetes_namespace_v1.meshcloud.metadata[0].name
    annotations = {
      "io.meshcloud/meshstack.replicator-kubernetes.version" = "1.0"
    }
  }
}

resource "kubernetes_secret_v1" "replicator" {
  metadata {
    name      = local.replicator_name
    namespace = kubernetes_namespace_v1.meshcloud.metadata[0].name
    annotations = {
      "kubernetes.io/service-account.name" = kubernetes_service_account_v1.replicator.metadata[0].name
    }
  }

  type = "kubernetes.io/service-account-token"
  # Kubernetes populates `data.token` asynchronously. Waiting for it (the provider default) is what
  # makes the token outputs reliably non-empty on the creating apply, with no sleep or second run.
  wait_for_service_account_token = true
}

resource "kubernetes_cluster_role_v1" "replicator" {
  metadata {
    name = local.replicator_name
    annotations = {
      "io.meshcloud/meshstack.replicator-kubernetes.version" = "1.0"
    }
  }

  rule {
    api_groups = [""]
    resources  = ["namespaces"]
    verbs      = ["get", "list", "watch", "create", "delete", "update"]
  }

  rule {
    api_groups = [""]
    resources  = ["resourcequotas", "resourcequotas/status"]
    verbs      = ["get", "list", "watch", "create", "delete", "deletecollection", "patch", "update"]
  }

  rule {
    api_groups = [""]
    resources  = ["appliedclusterresourcequotas", "clusterresourcequotas", "clusterresourcequotas/status"]
    verbs      = ["get", "list", "watch", "create", "delete", "deletecollection", "patch", "update"]
  }

  rule {
    api_groups = ["", "rbac.authorization.k8s.io"]
    resources  = ["roles", "rolebindings", "clusterroles", "clusterrolebindings"]
    verbs      = ["get", "list", "watch"]
  }

  rule {
    api_groups = ["", "rbac.authorization.k8s.io"]
    resources  = ["rolebindings"]
    verbs      = ["create", "delete", "update"]
  }

  rule {
    api_groups     = ["", "rbac.authorization.k8s.io"]
    resources      = ["clusterroles"]
    verbs          = ["bind"]
    resource_names = ["admin", "edit", "view"]
  }

  dynamic "rule" {
    for_each = var.replicator_additional_rules
    content {
      api_groups        = rule.value.api_groups
      resources         = rule.value.resources
      verbs             = rule.value.verbs
      resource_names    = rule.value.resource_names
      non_resource_urls = rule.value.non_resource_urls
    }
  }
}

resource "kubernetes_cluster_role_binding_v1" "replicator" {
  metadata {
    name = local.replicator_name
    annotations = {
      "io.meshcloud/meshstack.replicator-kubernetes.version" = "1.0"
    }
  }

  subject {
    kind      = "ServiceAccount"
    name      = kubernetes_service_account_v1.replicator.metadata[0].name
    namespace = kubernetes_namespace_v1.meshcloud.metadata[0].name
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = kubernetes_cluster_role_v1.replicator.metadata[0].name
  }
}

# ── Metering ────────────────────────────────────────────────────────────────

resource "kubernetes_service_account_v1" "metering" {
  count = var.metering_enabled ? 1 : 0

  metadata {
    name      = local.metering_name
    namespace = kubernetes_namespace_v1.meshcloud.metadata[0].name
    annotations = {
      "io.meshcloud/meshstack.metering-kubernetes.version" = "1.0"
    }
  }
}

resource "kubernetes_secret_v1" "metering" {
  count = var.metering_enabled ? 1 : 0

  metadata {
    name      = local.metering_name
    namespace = kubernetes_namespace_v1.meshcloud.metadata[0].name
    annotations = {
      "kubernetes.io/service-account.name" = kubernetes_service_account_v1.metering[0].metadata[0].name
    }
  }

  type                           = "kubernetes.io/service-account-token"
  wait_for_service_account_token = true
}

resource "kubernetes_cluster_role_v1" "metering" {
  count = var.metering_enabled ? 1 : 0

  metadata {
    name = local.metering_name
    annotations = {
      "io.meshcloud/meshstack.metering-kubernetes.version" = "1.0"
    }
  }

  rule {
    api_groups = [""]
    resources  = ["pods", "persistentvolumeclaims"]
    verbs      = ["get", "list"]
  }

  dynamic "rule" {
    for_each = var.metering_additional_rules
    content {
      api_groups        = rule.value.api_groups
      resources         = rule.value.resources
      verbs             = rule.value.verbs
      resource_names    = rule.value.resource_names
      non_resource_urls = rule.value.non_resource_urls
    }
  }
}

resource "kubernetes_cluster_role_binding_v1" "metering" {
  count = var.metering_enabled ? 1 : 0

  metadata {
    name = local.metering_name
    annotations = {
      "io.meshcloud/meshstack.metering-kubernetes.version" = "1.0"
    }
  }

  subject {
    kind      = "ServiceAccount"
    name      = kubernetes_service_account_v1.metering[0].metadata[0].name
    namespace = kubernetes_namespace_v1.meshcloud.metadata[0].name
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = kubernetes_cluster_role_v1.metering[0].metadata[0].name
  }
}

locals {
  replicator_name = "meshfed-service"
  metering_name   = "meshfed-metering"

  replicator_token = kubernetes_secret_v1.replicator.data["token"]
  metering_token   = var.metering_enabled ? kubernetes_secret_v1.metering[0].data["token"] : null
}
