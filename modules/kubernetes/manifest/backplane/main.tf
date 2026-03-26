resource "kubernetes_service_account" "bb_deployer" {
  metadata {
    name      = var.service_account_name
    namespace = var.namespace
  }
}

# Long-lived token secret bound to the service account.
resource "kubernetes_secret" "bb_deployer_token" {
  metadata {
    name      = "${var.service_account_name}-token"
    namespace = var.namespace
    annotations = {
      "kubernetes.io/service-account.name" = kubernetes_service_account.bb_deployer.metadata[0].name
    }
  }

  type = "kubernetes.io/service-account-token"
}

# Cluster-wide edit access so the SA can deploy Helm releases into any tenant namespace.
# 'edit' excludes RBAC and cluster-admin operations — much less privileged than admin kubeconfig.
resource "kubernetes_cluster_role_binding" "bb_deployer_edit" {
  metadata {
    name = var.service_account_name
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = "edit"
  }

  subject {
    kind      = "ServiceAccount"
    name      = kubernetes_service_account.bb_deployer.metadata[0].name
    namespace = var.namespace
  }
}
