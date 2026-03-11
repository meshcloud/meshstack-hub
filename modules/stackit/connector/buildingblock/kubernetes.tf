# Service account for forgejo actions to use
resource "kubernetes_service_account" "forgejo_actions" {
  metadata {
    name      = "forgejo-actions"
    namespace = var.namespace
  }
}

resource "kubernetes_secret" "forgejo_actions" {
  metadata {
    name      = "forgejo-actions"
    namespace = var.namespace
    annotations = {
      "kubernetes.io/service-account.name" = kubernetes_service_account.forgejo_actions.metadata[0].name
    }
  }

  type = "kubernetes.io/service-account-token"
}

resource "kubernetes_role_binding" "forgejo_actions" {
  metadata {
    name      = "forgejo-actions"
    namespace = var.namespace
  }
  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = "edit"
  }

  subject {
    kind      = "ServiceAccount"
    name      = kubernetes_service_account.forgejo_actions.metadata[0].name
    namespace = var.namespace
  }
}

resource "kubernetes_cluster_role_binding" "forgejo_actions_clusterissuer_access" {
  metadata {
    name = "forgejo-actions-clusterissuer-access-${var.namespace}"
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = "clusterissuer-reader" # This role is created in the backplane module
  }

  subject {
    kind      = "ServiceAccount"
    name      = kubernetes_service_account.forgejo_actions.metadata[0].name
    namespace = var.namespace
  }
}

resource "kubernetes_secret" "image_pull" {
  metadata {
    name      = "harbor-image-pull"
    namespace = var.namespace
  }

  type = "kubernetes.io/dockerconfigjson"

  data = {
    ".dockerconfigjson" = jsonencode({
      auths = {
        "${local.harbor.host}" = {
          username = local.harbor.username
          password = local.harbor.password
          auth     = base64encode("${local.harbor.username}:${local.harbor.password}")
        }
      }
    })
  }
}