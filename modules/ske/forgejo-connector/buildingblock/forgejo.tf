provider "forgejo" {
  # configured via env variables FORGEJO_HOST, FORGEJO_API_TOKEN
}

resource "forgejo_repository_action_secret" "kubeconfig" {
  repository_id = var.repository_id
  name          = "KUBECONFIG${var.repository_secret_name_suffix}"
  data = yamlencode(merge(local.kubeconfig, {
    current-context = local.kubeconfig_cluster_name

    users = [
      {
        name = kubernetes_service_account.forgejo_actions.metadata[0].name
        user = {
          "token" = kubernetes_secret.forgejo_actions.data.token
        }
      }
    ]

    contexts = [
      {
        name = local.kubeconfig_cluster_name
        context = {
          cluster   = local.kubeconfig_cluster_name
          namespace = var.namespace
          user      = kubernetes_service_account.forgejo_actions.metadata[0].name
        }
      }
    ]
  }))
}

resource "forgejo_repository_action_secret" "namespace" {
  repository_id = var.repository_id
  name          = "K8S_NAMESPACE${var.repository_secret_name_suffix}"
  data          = var.namespace
}
