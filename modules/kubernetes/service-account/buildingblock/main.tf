resource "kubernetes_service_account" "this" {
  metadata {
    name      = var.name
    namespace = var.namespace
  }
}

resource "kubernetes_secret" "this" {
  metadata {
    name      = kubernetes_service_account.this.metadata[0].name
    namespace = kubernetes_service_account.this.metadata[0].namespace
    annotations = {
      "kubernetes.io/service-account.name" = kubernetes_service_account.this.metadata[0].name
    }
  }

  type = "kubernetes.io/service-account-token"
}

resource "kubernetes_role_binding" "this" {
  metadata {
    name      = "${var.name}-${var.cluster_role}"
    namespace = var.namespace
  }
  subject {
    kind      = "ServiceAccount"
    name      = var.name
    namespace = var.namespace
  }
  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = var.cluster_role
  }
}
