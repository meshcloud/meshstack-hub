locals {
  kubeconfig_user = {
    users = [
      {
        name = kubernetes_service_account.github_actions.metadata[0].name
        user = {
          "token" = kubernetes_secret.github_actions.data.token
        }
      }
    ]

    contexts = [
      {
        name = "aks"
        context = {
          cluster   = "aks"
          namespace = var.namespace
          user      = kubernetes_service_account.github_actions.metadata[0].name
        }
      }
    ]
  }

  kubeconfig = merge(local.aks_kubeconfig_stub, local.kubeconfig_user)
}

resource "github_repository_environment" "env" {
  environment = var.github_environment_name
  repository  = var.github_repo
}

resource "github_actions_environment_secret" "kubeconfig" {
  environment     = var.github_environment_name
  repository      = github_repository_environment.env.repository
  secret_name     = "KUBECONFIG"
  plaintext_value = yamlencode(local.kubeconfig)

  depends_on = [
    github_repository_environment.env
  ]
}

resource "github_actions_environment_secret" "container_registry" {
  for_each = {
    host     = local.acr.host
    username = local.acr.username
    password = local.acr.password
  }

  environment     = var.github_environment_name
  repository      = github_repository_environment.env.repository
  secret_name     = "aks_container_registry_${each.key}"
  plaintext_value = each.value

  depends_on = [
    github_repository_environment.env
  ]
}

resource "github_actions_environment_variable" "additional" {
  for_each      = var.additional_environment_variables
  environment   = var.github_environment_name
  repository    = github_repository_environment.env.repository
  variable_name = each.key
  value         = each.value
  depends_on = [
    github_repository_environment.env
  ]
}
