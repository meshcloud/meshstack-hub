provider "forgejo" {
  # configured via env variables FORGEJO_HOST, FORGEJO_API_TOKEN
}

provider "restapi" {
  uri                  = data.external.repository_context.result.forgejo_host
  write_returns_object = false

  headers = {
    Authorization = "token ${data.external.repository_context.result.forgejo_api_token}"
    Content-Type  = "application/json"
  }
}

data "external" "repository_context" {
  program = ["python3", "${path.module}/get_forgejo_repository_context.py"]

  query = {
    FORGEJO_REPOSITORY_ID = tostring(var.repository_id)
  }
}

locals {
  repository_owner          = data.external.repository_context.result.owner
  repository_name           = data.external.repository_context.result.name
  repository_default_branch = data.external.repository_context.result.default_branch
  stage                     = lower(var.stage)

  action_secrets = {
    "KUBECONFIG_${upper(local.stage)}" = yamlencode(merge(local.kubeconfig, {
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

  action_variables = {
    "K8S_NAMESPACE_${upper(local.stage)}" = var.namespace
  }
}

resource "forgejo_repository_action_secret" "action_secrets" {
  for_each = local.action_secrets

  repository_id = var.repository_id
  name          = each.key
  data          = each.value
}

resource "restapi_object" "action_variables" {
  for_each = local.action_variables

  path          = "/api/v1/repos/${local.repository_owner}/${local.repository_name}/actions/variables"
  id_attribute  = "name"
  object_id     = each.key
  update_method = "PATCH"
  data = jsonencode({
    name  = each.key
    value = each.value
  })
  ignore_server_additions = true
}

resource "terraform_data" "await_pipeline_workflow" {
  depends_on = [
    forgejo_repository_action_secret.action_secrets,
    restapi_object.action_variables,
  ]

  provisioner "local-exec" {
    command = "${path.module}/trigger_and_await_forgejo_workflow.py"
    environment = {
      FORGEJO_REPOSITORY_ID       = tostring(var.repository_id)
      FORGEJO_WORKFLOW_NAME       = "pipeline.yaml"
      FORGEJO_WORKFLOW_ONLY_STAGE = local.stage
    }
  }
}
