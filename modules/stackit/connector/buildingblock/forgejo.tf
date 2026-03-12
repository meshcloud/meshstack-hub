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
  name  = var.forgejo_repository_name
  owner = var.forgejo_repository_owner
}

resource "forgejo_repository_action_secret" "kubeconfig" {
  repository_id = data.forgejo_repository.this.id
  name          = "KUBECONFIG"
  data          = yamlencode(local.kubeconfig)
}

resource "forgejo_repository_action_secret" "container_registry" {
  for_each = {
    HOST     = var.harbor_host
    USERNAME = var.harbor_username
    PASSWORD = var.harbor_password
  }

  repository_id = data.forgejo_repository.this.id
  name          = "STACKIT_HARBOR_${each.key}"
  data          = each.value
}

resource "forgejo_repository_action_secret" "additional" {
  for_each = var.additional_environment_variables

  repository_id = data.forgejo_repository.this.id
  name          = each.key
  data          = each.value
}