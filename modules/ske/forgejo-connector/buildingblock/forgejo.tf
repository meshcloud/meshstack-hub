locals {
  stage_suffix = upper(var.stage)

  kubeconfig_user = {
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
        name = "stackit_k8s"
        context = {
          cluster   = "stackit_k8s"
          namespace = var.namespace
          user      = kubernetes_service_account.forgejo_actions.metadata[0].name
        }
      }
    ]
  }
  kubeconfig = merge(local.stackit_kubeconfig_stub, local.kubeconfig_user)
}

resource "forgejo_repository_action_secret" "kubeconfig" {
  repository_id = var.repository_id
  name          = "KUBECONFIG_${local.stage_suffix}"
  data          = yamlencode(local.kubeconfig)
}

resource "forgejo_repository_action_secret" "namespace" {
  repository_id = var.repository_id
  name          = "K8S_NAMESPACE_${local.stage_suffix}"
  data          = var.namespace
}

resource "forgejo_repository_action_secret" "container_registry" {
  for_each = {
    HOST     = var.harbor_host
    USERNAME = var.harbor_username
    PASSWORD = var.harbor_password
  }

  repository_id = var.repository_id
  name          = "STACKIT_HARBOR_${each.key}"
  data          = each.value
}

resource "forgejo_repository_action_secret" "additional" {
  for_each = var.additional_environment_variables

  repository_id = var.repository_id
  name          = each.key
  data          = each.value
}
