resource "kubernetes_namespace" "connector" {
  metadata {
    name = var.namespace
  }

  lifecycle {
    # OpenShift annotates every namespace with its SCC UID range and SELinux labels.
    ignore_changes = [metadata[0].annotations]
  }
}

# Identity of the building block run. It needs no access to workloads: it only sets up the service
# account that GitHub Actions deploys with, inside the tenant namespace it is connected to.
resource "kubernetes_service_account" "connector" {
  metadata {
    name      = var.service_account_name
    namespace = kubernetes_namespace.connector.metadata[0].name
  }

  lifecycle {
    # OpenShift adds a dockercfg pull secret for the internal registry to every service account.
    ignore_changes = [image_pull_secret, secret]
  }
}

resource "kubernetes_secret" "connector_token" {
  metadata {
    name      = "${var.service_account_name}-token"
    namespace = kubernetes_namespace.connector.metadata[0].name
    annotations = {
      "kubernetes.io/service-account.name" = kubernetes_service_account.connector.metadata[0].name
    }
  }

  type = "kubernetes.io/service-account-token"
}

resource "kubernetes_cluster_role" "connector" {
  metadata {
    name = var.service_account_name
  }

  rule {
    api_groups = [""]
    resources  = ["serviceaccounts", "secrets"]
    verbs      = ["get", "list", "watch", "create", "update", "patch", "delete"]
  }

  rule {
    api_groups = ["rbac.authorization.k8s.io"]
    resources  = ["rolebindings"]
    verbs      = ["get", "list", "watch", "create", "update", "patch", "delete"]
  }

  # RBAC escalation prevention lets a subject grant a role only if it holds the role's permissions
  # itself or may `bind` it. `bind` on exactly these two keeps the run from handing out anything else.
  rule {
    api_groups     = ["rbac.authorization.k8s.io"]
    resources      = ["clusterroles"]
    verbs          = ["bind"]
    resource_names = ["edit", "system:image-builder"]
  }
}

resource "kubernetes_cluster_role_binding" "connector" {
  metadata {
    name = var.service_account_name
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = kubernetes_cluster_role.connector.metadata[0].name
  }

  subject {
    kind      = "ServiceAccount"
    name      = kubernetes_service_account.connector.metadata[0].name
    namespace = kubernetes_namespace.connector.metadata[0].name
  }
}
