locals {
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

data "forgejo_repository" "this" {
  name  = local.forgejo.repository_name
  owner = local.forgejo.repository_owner
}

resource "forgejo_repository_action_secret" "kubeconfig" {
  repository_id = data.forgejo_repository.this.id
  name          = "KUBECONFIG"
  data          = yamlencode(local.kubeconfig)
}

resource "forgejo_repository_action_secret" "container_registry" {
  for_each = {
    host     = local.harbor.host
    username = local.harbor.username
    password = local.harbor.password
  }

  repository_id = data.forgejo_repository.this.id
  name          = "stackit_harbor_${each.key}"
  data          = each.value
}

resource "forgejo_repository_action_secret" "additional" {
  for_each = var.additional_environment_variables

  repository_id = data.forgejo_repository.this.id
  name          = each.key
  data          = each.value
}