locals {
  # Several connectors may share a namespace, one per repository and environment.
  # Sanitize the repo name for kubernetes and add a hash to avoid collisions.
  repo_slug            = trim(substr(replace(lower(var.github_repo), "/[^a-z0-9-]+/", "-"), 0, 40), "-")
  service_account_name = "github-actions-${local.repo_slug}-${substr(sha256("${var.github_repo}/${var.github_environment_name}"), 0, 8)}"
}

# Credentials for this service account will be passed to GitHub.
resource "kubernetes_service_account_v1" "github_actions" {
  metadata {
    name      = local.service_account_name
    namespace = var.namespace
  }
}

resource "kubernetes_secret_v1" "github_actions" {
  metadata {
    name      = "${kubernetes_service_account_v1.github_actions.metadata[0].name}-token"
    namespace = var.namespace
    annotations = {
      "kubernetes.io/service-account.name" = kubernetes_service_account_v1.github_actions.metadata[0].name
    }
  }

  type = "kubernetes.io/service-account-token"
}

resource "kubernetes_role_binding_v1" "github_actions_edit" {
  metadata {
    name      = "${kubernetes_service_account_v1.github_actions.metadata[0].name}-edit"
    namespace = var.namespace
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = "edit"
  }

  subject {
    kind      = "ServiceAccount"
    name      = kubernetes_service_account_v1.github_actions.metadata[0].name
    namespace = var.namespace
  }
}
