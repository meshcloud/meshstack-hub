locals {
  kubeconfig = try(
    yamldecode(file("${path.module}/kubeconfig.yaml")),
    yamldecode(file("${path.module}/kubeconfig-mock.yaml"))
  )
  kubeconfig_cluster      = one(local.kubeconfig["clusters"])["cluster"]
  kubeconfig_cluster_name = one(local.kubeconfig["clusters"])["name"]
  kubeconfig_admin_user   = one(local.kubeconfig["users"])["user"]
}

provider "kubernetes" {
  host                   = local.kubeconfig_cluster["server"]
  cluster_ca_certificate = base64decode(local.kubeconfig_cluster["certificate-authority-data"])
  client_certificate     = base64decode(local.kubeconfig_admin_user["client-certificate-data"])
  client_key             = base64decode(local.kubeconfig_admin_user["client-key-data"])
}

# Service account for forgejo actions to use
resource "kubernetes_service_account" "forgejo_actions" {
  metadata {
    name      = "forgejo-actions"
    namespace = var.namespace
  }

  # Unfortunately, check blocks only supported in Terraform, not OpenTofu.
  lifecycle {
    precondition {
      condition     = local.kubeconfig_cluster["server"] != "https://example.invalid"
      error_message = "Mock kubeconfig detected. Ensure meshStack injected kubeconfig.yaml before apply."
    }
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

resource "random_string" "clusterissuer_reader_name_suffix" {
  length  = 8
  lower   = true
  upper   = false
  numeric = false
  special = false
}

# The ClusterIssuer access is needed so that SSL certificates can be issued for projects using the connector.
resource "kubernetes_cluster_role" "clusterissuer_reader" {
  metadata {
    name = "clusterissuer-reader-${random_string.clusterissuer_reader_name_suffix.result}" # random suffix ensures multiple roles can exist
  }

  rule {
    api_groups = ["cert-manager.io"]
    resources  = ["clusterissuers"]
    verbs      = ["get"]
  }
}

resource "kubernetes_cluster_role_binding" "forgejo_actions_clusterissuer_access" {
  metadata {
    name = "forgejo-actions-clusterissuer-access-${var.namespace}"
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = kubernetes_cluster_role.clusterissuer_reader.metadata[0].name
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
        (var.harbor_host) = {
          username = var.harbor_username
          password = var.harbor_password
          auth     = base64encode("${var.harbor_username}:${var.harbor_password}")
        }
      }
    })
  }
}

resource "kubernetes_secret" "additional" {
  for_each = var.additional_kubernetes_secrets

  metadata {
    name      = each.key
    namespace = var.namespace
  }

  type = "Opaque"

  data = each.value
}

resource "kubernetes_default_service_account" "namespace_default" {
  metadata {
    namespace = var.namespace
  }

  image_pull_secret {
    name = kubernetes_secret.image_pull.metadata[0].name
  }
}
