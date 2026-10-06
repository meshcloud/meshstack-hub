locals {
  # meshStack writes kubeconfig.yaml from a static FILE input at run time. The committed mock lets
  # the module validate without it, and the precondition below stops an apply against the mock.
  kubeconfig_path         = fileexists("${path.module}/kubeconfig.yaml") ? "${path.module}/kubeconfig.yaml" : "${path.module}/kubeconfig-mock.yaml"
  kubeconfig              = yamldecode(file(local.kubeconfig_path))
  kubeconfig_cluster      = one(local.kubeconfig["clusters"])["cluster"]
  kubeconfig_cluster_name = one(local.kubeconfig["clusters"])["name"]
}

provider "kubernetes" {
  config_path = local.kubeconfig_path
}

resource "random_string" "suffix" {
  length  = 5
  lower   = true
  upper   = false
  numeric = true
  special = false
}

# Service account for forgejo actions to use
resource "kubernetes_service_account" "forgejo_actions" {
  metadata {
    name      = "forgejo-actions-${random_string.suffix.result}"
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
    name      = "forgejo-actions-${random_string.suffix.result}"
    namespace = var.namespace
    annotations = {
      "kubernetes.io/service-account.name" = kubernetes_service_account.forgejo_actions.metadata[0].name
    }
  }

  type = "kubernetes.io/service-account-token"
}

resource "kubernetes_role_binding" "forgejo_actions" {
  metadata {
    name      = "forgejo-actions-${random_string.suffix.result}"
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

# The ClusterIssuer access is needed so that SSL certificates can be issued for projects using the connector.
resource "kubernetes_cluster_role" "clusterissuer_reader" {
  metadata {
    name = "${var.namespace}-clusterissuer-reader-${random_string.suffix.result}"
  }

  rule {
    api_groups = ["cert-manager.io"]
    resources  = ["clusterissuers"]
    verbs      = ["get"]
  }
}

resource "kubernetes_cluster_role_binding" "forgejo_actions_clusterissuer_access" {
  metadata {
    name = "${var.namespace}-forgejo-actions-clusterissuer-access-${random_string.suffix.result}"
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
    name      = "harbor-image-pull-${random_string.suffix.result}"
    namespace = var.namespace
  }

  type = "kubernetes.io/dockerconfigjson"
  data = {
    ".dockerconfigjson" = jsonencode({
      auths = {
        (var.harbor_host) = {
          username = local.registry_pull["username"]
          password = local.registry_pull["password"]
          auth     = base64encode("${local.registry_pull["username"]}:${local.registry_pull["password"]}")
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
  data = data.vault_kv_secret_v2.additional[each.key].data
}

resource "kubernetes_default_service_account" "this" {
  metadata {
    namespace = var.namespace
  }

  image_pull_secret {
    name = kubernetes_secret.image_pull.metadata[0].name
  }
}
