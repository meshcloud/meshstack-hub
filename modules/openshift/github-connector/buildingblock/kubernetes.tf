# Identity GitHub Actions deploys with. It is bound to this namespace only.
resource "kubernetes_service_account" "github_actions" {
  metadata {
    name      = "github-actions"
    namespace = var.namespace
  }

  lifecycle {
    # OpenShift adds a dockercfg pull secret for the internal registry to every service account.
    ignore_changes = [image_pull_secret, secret]
  }
}

resource "kubernetes_secret" "github_actions" {
  metadata {
    name      = "github-actions-token"
    namespace = var.namespace
    annotations = {
      "kubernetes.io/service-account.name" = kubernetes_service_account.github_actions.metadata[0].name
    }
  }

  type = "kubernetes.io/service-account-token"
}

resource "kubernetes_role_binding" "github_actions_edit" {
  metadata {
    name      = "github-actions-edit"
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

# Lets the pipeline push to the image streams of this namespace in the internal registry. Pods of
# the namespace pull from them without a pull secret, because OpenShift grants every service
# account image pull access within its own namespace.
resource "kubernetes_role_binding" "github_actions_image_builder" {
  metadata {
    name      = "github-actions-image-builder"
    namespace = var.namespace
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = "system:image-builder"
  }

  subject {
    kind      = "ServiceAccount"
    name      = kubernetes_service_account.github_actions.metadata[0].name
    namespace = var.namespace
  }
}
