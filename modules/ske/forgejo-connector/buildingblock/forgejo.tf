provider "forgejo" {
  # configured via env variables FORGEJO_HOST, FORGEJO_API_TOKEN
}

locals {
  action_variables = {
    "K8S_NAMESPACE_${upper(var.stage)}" = var.namespace
    "APP_HOSTNAME_${upper(var.stage)}"  = var.app_hostname
  }
  action_secrets = {
    "KUBECONFIG_${upper(var.stage)}" = yamlencode(merge(local.kubeconfig, {
      current-context = local.kubeconfig_cluster_name
      # Note: Overwriting the users is crucial here to avoid passing down the admin user to the tenant-sliced K8s slices.
      users = [{
        name = kubernetes_service_account.forgejo_actions.metadata[0].name
        user = {
          "token" = kubernetes_secret.forgejo_actions.data.token
        }
      }]
      contexts = [{
        name = local.kubeconfig_cluster_name
        context = {
          cluster   = local.kubeconfig_cluster_name
          namespace = var.namespace
          user      = kubernetes_service_account.forgejo_actions.metadata[0].name
        }
      }]
    }))
  }
}

module "action_secrets_and_variables" {
  source = "github.com/meshcloud/meshstack-hub//modules/stackit/git-repository/buildingblock/action-variables-and-secrets?ref=d01aad9eb8beffa2a4686d546ccda7dd66bb187b"
  providers = {
    restapi.action_variable = restapi.action_variable
    restapi.action_secret   = restapi.action_secret
  }

  repository_id    = var.repository_id
  action_variables = local.action_variables
  action_secrets   = local.action_secrets
}

resource "terraform_data" "await_pipeline_workflow" {
  depends_on = [
    module.action_secrets_and_variables,
  ]

  triggers_replace = [
    sha256(file("${path.module}/trigger_and_await_forgejo_workflow.py")),
    nonsensitive(sha256(jsonencode(local.action_secrets))),
    sha256(jsonencode(local.action_variables)),
  ]

  provisioner "local-exec" {
    command = "${path.module}/trigger_and_await_forgejo_workflow.py"
    environment = {
      REPOSITORY_ID               = tostring(var.repository_id)
      WORKFLOW_NAME               = "pipeline.yaml"
      WORKFLOW_ONLY_STAGE         = var.stage
      EXPECTED_WORKFLOW_TASK_NAME = "deploy_${var.stage}"
      WORKFLOW_RUN_TITLE          = "Triggered by meshStack Forgejo Connector ${title(var.stage)}"
    }
  }
}
