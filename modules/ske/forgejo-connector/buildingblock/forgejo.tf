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

  action_secrets = {
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

  action_variables = {
    "K8S_NAMESPACE_${upper(var.stage)}" = var.namespace
    "APP_HOSTNAME_${upper(var.stage)}"  = var.app_hostname
  }
}

resource "restapi_object" "action_secret" {
  for_each = local.action_secrets

  path         = "/api/v1/repos/${local.repository_owner}/${local.repository_name}/actions/secrets/${each.key}"
  create_path  = "/api/v1/repos/${local.repository_owner}/${local.repository_name}/actions/secrets/${each.key}"
  update_path  = "/api/v1/repos/${local.repository_owner}/${local.repository_name}/actions/secrets/${each.key}"
  destroy_path = "/api/v1/repos/${local.repository_owner}/${local.repository_name}/actions/secrets/${each.key}"
  read_path    = "/api/v1/repos/${local.repository_owner}/${local.repository_name}/actions/secrets"
  id_attribute = "name"
  object_id    = each.key

  create_method  = "PUT"
  update_method  = "PUT"
  destroy_method = "DELETE"

  read_search = {
    results_key  = "data"
    search_key   = "name"
    search_value = each.key
  }

  data = jsonencode({
    data = each.value
  })

  ignore_server_additions = true
}

resource "restapi_object" "action_variable" {
  for_each = local.action_variables

  path         = "/api/v1/repos/${local.repository_owner}/${local.repository_name}/actions/variables/${each.key}"
  create_path  = "/api/v1/repos/${local.repository_owner}/${local.repository_name}/actions/variables/${each.key}"
  update_path  = "/api/v1/repos/${local.repository_owner}/${local.repository_name}/actions/variables/${each.key}"
  destroy_path = "/api/v1/repos/${local.repository_owner}/${local.repository_name}/actions/variables/${each.key}"
  read_path    = "/api/v1/repos/${local.repository_owner}/${local.repository_name}/actions/variables/${each.key}"
  id_attribute = "name"
  object_id    = each.key

  create_method  = "POST"
  update_method  = "PUT"
  destroy_method = "DELETE"

  data = jsonencode({
    name  = each.key
    value = each.value
  })

  ignore_server_additions = true
}

resource "terraform_data" "await_pipeline_workflow" {
  depends_on = [
    restapi_object.action_secret,
    restapi_object.action_variable,
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

moved {
  from = restapi_object.action_variables
  to   = restapi_object.action_variable
}
