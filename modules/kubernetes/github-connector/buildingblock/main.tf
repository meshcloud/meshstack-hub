locals {
  kubeconfig = yamlencode({
    apiVersion      = "v1"
    kind            = "Config"
    current-context = "kubernetes"

    clusters = [{
      name = "kubernetes"
      cluster = {
        server                     = var.kubernetes_api.server
        certificate-authority-data = base64encode(var.kubernetes_api.cluster_ca_certificate)
      }
    }]

    users = [{
      name = kubernetes_service_account_v1.github_actions.metadata[0].name
      user = {
        token = kubernetes_secret_v1.github_actions.data["token"]
      }
    }]

    contexts = [{
      name = "kubernetes"
      context = {
        cluster   = "kubernetes"
        namespace = var.namespace
        user      = kubernetes_service_account_v1.github_actions.metadata[0].name
      }
    }]
  })
}

resource "github_repository_environment" "this" {
  environment = var.github_environment_name
  repository  = var.github_repo
}

resource "github_actions_environment_secret" "kubeconfig" {
  environment     = github_repository_environment.this.environment
  repository      = github_repository_environment.this.repository
  secret_name     = "KUBECONFIG"
  plaintext_value = local.kubeconfig
}

resource "github_actions_environment_variable" "k8s_namespace" {
  environment   = github_repository_environment.this.environment
  repository    = github_repository_environment.this.repository
  variable_name = "K8S_NAMESPACE"
  value         = var.namespace
}
