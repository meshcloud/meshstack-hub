# In-cluster identities meshStack authenticates with.
#
# The replicator creates namespaces, resource quotas and role bindings for every tenant. The
# metering service account reads pods and persistent volume claims to collect usage data. Both are
# plain Kubernetes service accounts with a long-lived token, so no cloud identity provider is
# involved and the module works on any conformant cluster.

resource "kubernetes_namespace" "meshcloud" {
  metadata {
    name = var.service_account_namespace
  }
}

# ── Replicator ──────────────────────────────────────────────────────────────

resource "kubernetes_service_account" "replicator" {
  metadata {
    name      = local.replicator_name
    namespace = kubernetes_namespace.meshcloud.metadata[0].name
    annotations = {
      "io.meshcloud/meshstack.replicator-kubernetes.version" = "1.0"
    }
  }
}

resource "kubernetes_secret" "replicator" {
  metadata {
    name      = local.replicator_name
    namespace = kubernetes_namespace.meshcloud.metadata[0].name
    annotations = {
      "kubernetes.io/service-account.name" = kubernetes_service_account.replicator.metadata[0].name
    }
  }

  type                           = "kubernetes.io/service-account-token"
  wait_for_service_account_token = true
}

resource "kubernetes_cluster_role" "replicator" {
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

resource "kubernetes_cluster_role_binding" "replicator" {
  metadata {
    name = local.replicator_name
    annotations = {
      "io.meshcloud/meshstack.replicator-kubernetes.version" = "1.0"
    }
  }

  subject {
    kind      = "ServiceAccount"
    name      = kubernetes_service_account.replicator.metadata[0].name
    namespace = kubernetes_namespace.meshcloud.metadata[0].name
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = kubernetes_cluster_role.replicator.metadata[0].name
  }
}

# ── Metering ────────────────────────────────────────────────────────────────

resource "kubernetes_service_account" "metering" {
  count = var.metering_enabled ? 1 : 0

  metadata {
    name      = local.metering_name
    namespace = kubernetes_namespace.meshcloud.metadata[0].name
    annotations = {
      "io.meshcloud/meshstack.metering-kubernetes.version" = "1.0"
    }
  }
}

resource "kubernetes_secret" "metering" {
  count = var.metering_enabled ? 1 : 0

  metadata {
    name      = local.metering_name
    namespace = kubernetes_namespace.meshcloud.metadata[0].name
    annotations = {
      "kubernetes.io/service-account.name" = kubernetes_service_account.metering[0].metadata[0].name
    }
  }

  type                           = "kubernetes.io/service-account-token"
  wait_for_service_account_token = true
}

resource "kubernetes_cluster_role" "metering" {
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

resource "kubernetes_cluster_role_binding" "metering" {
  count = var.metering_enabled ? 1 : 0

  metadata {
    name = local.metering_name
    annotations = {
      "io.meshcloud/meshstack.metering-kubernetes.version" = "1.0"
    }
  }

  subject {
    kind      = "ServiceAccount"
    name      = kubernetes_service_account.metering[0].metadata[0].name
    namespace = kubernetes_namespace.meshcloud.metadata[0].name
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = kubernetes_cluster_role.metering[0].metadata[0].name
  }
}

locals {
  name_suffix     = var.resource_name_suffix == "" ? "" : "-${var.resource_name_suffix}"
  replicator_name = "meshfed-service${local.name_suffix}"
  metering_name   = "meshfed-metering${local.name_suffix}"

  replicator_token = kubernetes_secret.replicator.data["token"]
  metering_token   = var.metering_enabled ? kubernetes_secret.metering[0].data["token"] : null
}
