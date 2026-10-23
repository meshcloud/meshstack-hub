# RBAC refuses a RoleBinding to a role its creator doesn't hold, unless the creator has `bind` on
# that role. `bind` on the one role alone keeps the building block from handing out anything stronger.
resource "kubernetes_cluster_role_v1" "grant_access" {
  metadata {
    name = "${var.service_account_id}-grant-access"
  }

  rule {
    api_groups = ["rbac.authorization.k8s.io"]
    resources  = ["rolebindings"]
    verbs      = ["get", "list", "create", "update", "patch", "delete"]
  }

  rule {
    api_groups     = ["rbac.authorization.k8s.io"]
    resources      = ["clusterroles"]
    verbs          = ["bind"]
    resource_names = [var.cluster_role]
  }
}

# Bound per namespace, so the building block can only grant access to the namespaces offered.
resource "kubernetes_role_binding_v1" "grant_access" {
  for_each = var.namespaces

  metadata {
    name      = kubernetes_cluster_role_v1.grant_access.metadata[0].name
    namespace = each.value
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = kubernetes_cluster_role_v1.grant_access.metadata[0].name
  }

  subject {
    api_group = "rbac.authorization.k8s.io"
    kind      = "User"
    name      = google_service_account.buildingblock.email
  }
}
