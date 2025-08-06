# Service account for GHA to use
resource "kubernetes_service_account" "github_actions" {
  metadata {
    name      = "github-actions"
    namespace = var.namespace
  }
}

resource "kubernetes_secret" "github_actions" {
  metadata {
    name      = "github-actions"
    namespace = var.namespace
    annotations = {
      "kubernetes.io/service-account.name" = kubernetes_service_account.github_actions.metadata[0].name
    }
  }

  type = "kubernetes.io/service-account-token"
}

resource "kubernetes_role_binding" "github_actions" {
  metadata {
    name      = "github-actions"
    namespace = var.namespace
  }
  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = "edit"
  }

  subject {
    kind      = "ServiceAccount"
    name      = kubernetes_service_account.github_actions.metadata[0].name
    namespace = var.namespace
  }
}

# The ClusterIssuer is needed so that SSL certificates can be issued for projects using the GitHub Actions Connector.
resource "kubernetes_cluster_role" "clusterissuer_reader" {
  metadata {
    name = "clusterissuer-reader"
  }

  rule {
    api_groups = ["cert-manager.io"]
    resources  = ["clusterissuers"]
    verbs      = ["get"]
  }
}

resource "kubernetes_cluster_role_binding" "github_actions_clusterissuer_access" {
  metadata {
    name = "github-actions-clusterissuer-access"
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = kubernetes_cluster_role.clusterissuer_reader.metadata[0].name
  }

  subject {
    kind      = "ServiceAccount"
    name      = kubernetes_service_account.github_actions.metadata[0].name
    namespace = var.namespace
  }
}

resource "kubernetes_secret" "image_pull" {
  metadata {
    name      = "acr-image-pull"
    namespace = var.namespace
  }

  type = "kubernetes.io/dockerconfigjson"

  data = {
    ".dockerconfigjson" = jsonencode({
      auths = {
        "${local.acr.host}" = {
          username = local.acr.username
          password = local.acr.password
          auth     = base64encode("${local.acr.username}:${local.acr.password}")
        }
      }
    })
  }
}
