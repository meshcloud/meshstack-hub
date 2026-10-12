locals {
  kubeconfig = yamlencode({
    apiVersion      = "v1"
    kind            = "Config"
    current-context = "openshift"

    clusters = [{
      name = "openshift"
      cluster = {
        server                     = var.kubernetes_api.server
        certificate-authority-data = base64encode(var.kubernetes_api.cluster_ca_certificate)
      }
    }]

    users = [{
      name = kubernetes_service_account.github_actions.metadata[0].name
      user = {
        token = kubernetes_secret.github_actions.data["token"]
      }
    }]

    contexts = [{
      name = "openshift"
      context = {
        cluster   = "openshift"
        namespace = var.namespace
        user      = kubernetes_service_account.github_actions.metadata[0].name
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

# The internal registry accepts the service account token as password for any user name.
resource "github_actions_environment_secret" "registry_token" {
  environment     = github_repository_environment.this.environment
  repository      = github_repository_environment.this.repository
  secret_name     = "OPENSHIFT_REGISTRY_TOKEN"
  plaintext_value = kubernetes_secret.github_actions.data["token"]
}

resource "github_actions_environment_variable" "this" {
  for_each = merge(var.additional_environment_variables, {
    OPENSHIFT_NAMESPACE = var.namespace
    OPENSHIFT_REGISTRY  = var.registry_host
  })

  environment   = github_repository_environment.this.environment
  repository    = github_repository_environment.this.repository
  variable_name = each.key
  value         = each.value
}

resource "terraform_data" "workflow_dispatch" {
  lifecycle {
    enabled = var.workflow_filename != ""
  }

  triggers_replace = [
    sha256(local.kubeconfig),
    var.registry_host,
  ]

  provisioner "local-exec" {
    command     = "${path.module}/dispatch_github_workflow.py"
    interpreter = ["python3"]
    environment = {
      GITHUB_REPO       = var.github_repo
      WORKFLOW_FILENAME = var.workflow_filename
      WORKFLOW_REF      = var.deploy_branch
      # GITHUB_OWNER and the GITHUB_APP_* credentials come from the run's environment inputs.
    }
  }

  depends_on = [
    github_actions_environment_secret.kubeconfig,
    github_actions_environment_secret.registry_token,
    github_actions_environment_variable.this,
  ]
}
