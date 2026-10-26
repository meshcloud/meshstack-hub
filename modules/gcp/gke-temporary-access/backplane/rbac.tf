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

# Cluster-wide, because RBAC can't exclude namespaces. The admission policy keeps the building block
# out of the forbidden ones.
resource "kubernetes_cluster_role_binding_v1" "grant_access" {
  # Grant the rights only once the policy that restricts them is in force.
  depends_on = [kubernetes_manifest.rolebinding_policy_binding]

  metadata {
    name = kubernetes_cluster_role_v1.grant_access.metadata[0].name
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
