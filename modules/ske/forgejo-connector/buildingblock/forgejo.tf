provider "forgejo" {
  # configured via env variables FORGEJO_HOST, FORGEJO_API_TOKEN
}

locals {
  registry_wired = var.container_registry_access_credentials != null

  # An empty credential still produces a usable dockerconfigjson, so pods start and pull public
  # images rather than failing on a missing secret.
  registry_pull = local.registry_wired ? var.container_registry_access_credentials.pull : { user = "", password = "" }

  action_variables = {
    "K8S_NAMESPACE_${upper(var.stage)}" = var.namespace
    "APP_HOSTNAME_${upper(var.stage)}"  = var.app_hostname
  }

  action_secrets = merge(local.registry_wired ? {
    HARBOR_USERNAME = var.container_registry_access_credentials.push.user
    HARBOR_PASSWORD = var.container_registry_access_credentials.push.password
    } : {}, {
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
  })
}

resource "forgejo_repository_action_variable" "this" {
  for_each = local.action_variables

  # Creating a variable fails while one with the same name exists, so the legacy one must be gone first.
  depends_on = [restapi_object.legacy_action_variable]

  repository_id = var.repository_id
  name          = each.key
  data          = each.value
}

# Only the names are unwrapped, and they have to be: they are the resource instance keys.
resource "forgejo_repository_action_secret" "this" {
  for_each = nonsensitive(toset(keys(local.action_secrets)))

  # Without this, deleting a legacy secret can run after writing its replacement and remove it.
  depends_on = [restapi_object.legacy_action_secret]

  repository_id = var.repository_id
  name          = each.key
  data          = local.action_secrets[each.key]
}

# Older versions created these as restapi objects. Moving them here deletes them before the forgejo
# resources replace them. Remove once every building block has run on this version.
resource "restapi_object" "legacy_action_variable" {
  for_each = toset([])

  provider = restapi.with_returned_object
  path     = "/"
  data     = "{}"
}

resource "restapi_object" "legacy_action_secret" {
  for_each = toset([])

  provider = restapi.without_returned_object
  path     = "/"
  data     = "{}"
}

moved {
  from = module.action_secrets_and_variables.restapi_object.action_variable
  to   = restapi_object.legacy_action_variable
}

moved {
  from = module.action_secrets_and_variables.restapi_object.action_secret
  to   = restapi_object.legacy_action_secret
}

resource "terraform_data" "await_pipeline_workflow" {
  depends_on = [
    forgejo_repository_action_variable.this,
    forgejo_repository_action_secret.this,
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
