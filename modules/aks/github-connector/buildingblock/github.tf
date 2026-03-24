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
  # Map GitHub environment name to the corresponding branch:
  # 'production' -> 'release', everything else (e.g. 'development') -> 'main'
  workflow_ref = var.github_environment_name == "production" ? "release" : "main"
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

# Trigger workflow_dispatch once for this connector's branch after all secrets
# and variables are in place. Each connector instance targets one branch (dev→main,
# prod→release), so this fires exactly once per connector per apply.
resource "terraform_data" "workflow_dispatch" {
  count = var.workflow_filename != "" ? 1 : 0

  triggers_replace = [
    sha256(yamlencode(local.kubeconfig)),
    local.acr.host,
  ]

  provisioner "local-exec" {
    command     = "${path.module}/dispatch_github_workflow.py"
    interpreter = ["python3"]
    environment = {
      GITHUB_REPO       = var.github_repo
      WORKFLOW_FILENAME = var.workflow_filename
      WORKFLOW_REF      = local.workflow_ref
      # GITHUB_APP_ID, GITHUB_APP_INSTALLATION_ID, GITHUB_APP_PEM_FILE are
      # already in the environment from the building block runner's env vars.
    }
  }

  depends_on = [
    github_actions_environment_secret.kubeconfig,
    github_actions_environment_secret.container_registry,
    github_actions_environment_variable.additional,
  ]
}
