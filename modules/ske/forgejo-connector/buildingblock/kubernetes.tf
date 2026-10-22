locals {
  admin_kubeconfig = yamldecode(ephemeral.vault_kv_secret_v2.kubeconfig.data.kubeconfig)
}

provider "kubernetes" {
  host                   = one(local.admin_kubeconfig.clusters).cluster.server
  cluster_ca_certificate = base64decode(one(local.admin_kubeconfig.clusters).cluster["certificate-authority-data"])
  token                  = one(local.admin_kubeconfig.users).user.token
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

  type             = "kubernetes.io/dockerconfigjson"
  data_wo_revision = var.secrets_revision
  data_wo          = jsondecode(ephemeral.vault_generic_secret.registry.data_json)["pull-kubernetes-secret"]
}

resource "kubernetes_secret" "additional" {
  for_each = var.additional_kubernetes_secrets

  metadata {
    name      = each.key
    namespace = var.namespace
  }

  type             = "Opaque"
  data_wo          = jsondecode(ephemeral.vault_generic_secret.additional[each.key].data_json)["kubernetes-secret"]
  data_wo_revision = var.secrets_revision
}

resource "kubernetes_default_service_account" "this" {
  metadata {
    namespace = var.namespace
  }

  image_pull_secret {
    name = kubernetes_secret.image_pull.metadata[0].name
  }
}
