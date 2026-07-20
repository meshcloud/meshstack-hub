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
  source = "github.com/meshcloud/meshstack-hub//modules/stackit/git-repository/buildingblock/action-variables-and-secrets?ref=525d0fcf2795261949e1941a3b774e7ce5e2fd07"
  providers = {
    restapi.with_returned_object    = restapi.with_returned_object
    restapi.without_returned_object = restapi.without_returned_object
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

  # This relies on the actual workflow definition in
  # https://github.com/likvid-bank/starterkit-template-stackit-ai-summarizer/tree/ffba93a6e7e1aa12032b5ae5697a5dcdc481a74b/.forgejo/workflows
  provisioner "local-exec" {
    # The script polls indefinitely (Forgejo exposes no run-level status to bound
    # on); cap the wait at 15 minutes here since local-exec has no timeout option.
    command = "timeout 900 ${path.module}/trigger_and_await_forgejo_workflow.py"
    environment = {
      REPOSITORY_ID = tostring(var.repository_id)
      WORKFLOW_NAME = "pipeline.yaml"
      BRANCH        = var.stage
      # Jobs (as named in /actions/tasks) that must all succeed for the run to
      # count as done. Required because Forgejo's API exposes no run-level status
      # and needs-gated jobs only appear once their dependency finishes; see the
      # script header for details.
      EXPECTED_JOBS = "build_image,deploy"
    }
  }
}
