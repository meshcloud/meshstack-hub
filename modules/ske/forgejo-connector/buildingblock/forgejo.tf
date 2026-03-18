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
  repository_owner = data.external.repository_context.result.owner
  repository_name  = data.external.repository_context.result.name

  action_secret = {
    "KUBECONFIG_${upper(var.stage)}" = yamlencode(merge(local.kubeconfig, {
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

  action_variable = {
    "K8S_NAMESPACE_${upper(var.stage)}" = var.namespace
  }
}

resource "forgejo_repository_action_secret" "this" {
  for_each = local.action_secret

  repository_id = var.repository_id
  name          = each.key
  data          = each.value
}

resource "restapi_object" "action_variable" {
  for_each = local.action_variable

  path          = "/api/v1/repos/${local.repository_owner}/${local.repository_name}/actions/variables/${each.key}"
  id_attribute  = "name"
  object_id     = each.key
  update_method = "PUT"
  data = jsonencode({
    value = each.value
  })
  ignore_server_additions = true
}

resource "terraform_data" "await_pipeline_workflow" {
  depends_on = [
    forgejo_repository_action_secret.this,
    restapi_object.action_variable,
  ]

  triggers_replace = [
    sha256(file("${path.module}/trigger_and_await_forgejo_workflow.py")),
    nonsensitive(sha256(jsonencode(local.action_secret))),
    sha256(jsonencode(local.action_variable)),
  ]

  provisioner "local-exec" {
    command = "${path.module}/trigger_and_await_forgejo_workflow.py"
    environment = {
      REPOSITORY_ID               = tostring(var.repository_id)
      WORKFLOW_NAME               = "pipeline.yaml"
      WORKFLOW_ONLY_STAGE         = var.stage
      EXPECTED_WORKFLOW_TASK_NAME = "deploy_${var.stage}"
    }
  }
}

moved {
  from = forgejo_repository_action_secret.action_secrets
  to   = forgejo_repository_action_secret.this
}

moved {
  from = restapi_object.action_variables
  to   = restapi_object.action_variable
}
