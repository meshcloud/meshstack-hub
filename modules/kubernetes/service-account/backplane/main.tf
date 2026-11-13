# The identity the definition creates service accounts with. It may only manage service accounts,
# their token secrets and role bindings, and bind no role beyond `var.cluster_roles`.
resource "kubernetes_service_account_v1" "deployer" {
  metadata {
    name      = var.service_account_name
    namespace = var.namespace
  }
}

resource "kubernetes_secret_v1" "deployer_token" {
  metadata {
    name      = "${var.service_account_name}-token"
    namespace = var.namespace
    annotations = {
      "kubernetes.io/service-account.name" = kubernetes_service_account_v1.deployer.metadata[0].name
    }
  }

  type                           = "kubernetes.io/service-account-token"
  wait_for_service_account_token = true
}

resource "kubernetes_cluster_role_v1" "deployer" {
  metadata {
    name = var.service_account_name
  }

  # No list or watch, so it cannot enumerate the secrets of other namespaces.
  rule {
    api_groups = [""]
    resources  = ["serviceaccounts", "secrets"]
    verbs      = ["get", "create", "update", "patch", "delete"]
  }

  # Without ClusterRoleBindings an ordered service account only ever gets rights in its own namespace.
  rule {
    api_groups = ["rbac.authorization.k8s.io"]
    resources  = var.bind_cluster_wide ? ["rolebindings", "clusterrolebindings"] : ["rolebindings"]
    verbs      = ["get", "create", "update", "patch", "delete"]
  }

  # Binding a role needs either every permission of the role or `bind` on it.
  rule {
    api_groups     = ["rbac.authorization.k8s.io"]
    resources      = ["clusterroles"]
    verbs          = ["bind"]
    resource_names = var.cluster_roles
  }
}

resource "kubernetes_cluster_role_binding_v1" "deployer" {
  metadata {
    name = var.service_account_name
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = kubernetes_cluster_role_v1.deployer.metadata[0].name
  }

  subject {
    kind      = "ServiceAccount"
    name      = kubernetes_service_account_v1.deployer.metadata[0].name
    namespace = var.namespace
  }
}
