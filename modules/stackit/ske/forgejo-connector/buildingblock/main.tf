# ── Kubernetes service account for Forgejo Actions ────────────────────────────

resource "kubernetes_service_account" "forgejo_actions" {
  metadata {
    name      = "forgejo-actions"
    namespace = var.namespace
  }
}

resource "kubernetes_secret" "forgejo_actions_token" {
  metadata {
    name      = "forgejo-actions-token"
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

# ── Generate kubeconfig for the service account ──────────────────────────────

locals {
  kubeconfig = yamlencode({
    apiVersion      = "v1"
    kind            = "Config"
    current-context = "ske"
    clusters = [{
      name = "ske"
      cluster = {
        server                     = var.cluster_server
        certificate-authority-data = var.cluster_ca_certificate
      }
    }]
    users = [{
      name = kubernetes_service_account.forgejo_actions.metadata[0].name
      user = {
        token = kubernetes_secret.forgejo_actions_token.data["token"]
      }
    }]
    contexts = [{
      name = "ske"
      context = {
        cluster   = "ske"
        namespace = var.namespace
        user      = kubernetes_service_account.forgejo_actions.metadata[0].name
      }
    }]
  })
}

# ── Store kubeconfig as Forgejo Actions secret ────────────────────────────────

resource "gitea_repository_actions_secret" "kubeconfig" {
  repository_owner = var.gitea_organization
  repository       = var.repository_name
  secret_name      = "KUBECONFIG"
  secret_value     = local.kubeconfig
}

# ── Harbor container registry secrets (optional) ─────────────────────────────

resource "gitea_repository_actions_secret" "harbor_url" {
  count            = var.harbor != null ? 1 : 0
  repository_owner = var.gitea_organization
  repository       = var.repository_name
  secret_name      = "HARBOR_URL"
  secret_value     = var.harbor.url
}

resource "gitea_repository_actions_secret" "harbor_username" {
  count            = var.harbor != null ? 1 : 0
  repository_owner = var.gitea_organization
  repository       = var.repository_name
  secret_name      = "HARBOR_USERNAME"
  secret_value     = var.harbor.robot_username
}

resource "gitea_repository_actions_secret" "harbor_token" {
  count            = var.harbor != null ? 1 : 0
  repository_owner = var.gitea_organization
  repository       = var.repository_name
  secret_name      = "HARBOR_TOKEN"
  secret_value     = var.harbor.robot_token
}

resource "kubernetes_secret" "harbor_pull_secret" {
  count = var.harbor != null ? 1 : 0

  metadata {
    name      = "harbor-pull-secret"
    namespace = var.namespace
  }

  type = "kubernetes.io/dockerconfigjson"

  data = {
    ".dockerconfigjson" = jsonencode({
      auths = {
        (var.harbor.url) = {
          username = var.harbor.robot_username
          password = var.harbor.robot_token
          auth     = base64encode("${var.harbor.robot_username}:${var.harbor.robot_token}")
        }
      }
    })
  }
}
