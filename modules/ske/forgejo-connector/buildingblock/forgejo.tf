provider "forgejo" {
  # configured via env variables FORGEJO_HOST, FORGEJO_API_TOKEN
}

data "external" "forgejo_env" {
  program = ["python3", "-c", <<-PY
import json
import os

print(json.dumps({
  "forgejo_host": os.environ["FORGEJO_HOST"],
  "forgejo_api_token": os.environ["FORGEJO_API_TOKEN"],
}))
PY
  ]
}

provider "restapi" {
  uri                  = data.external.forgejo_env.result.forgejo_host
  write_returns_object = false

  headers = {
    Authorization = "token ${data.external.forgejo_env.result.forgejo_api_token}"
    Content-Type  = "application/json"
  }
}

data "external" "repository" {
  program = ["python3", "-c", <<-PY
import json
import sys
import urllib.request

query = json.loads(sys.stdin.read())
host = query["FORGEJO_HOST"].rstrip("/")
token = query["FORGEJO_API_TOKEN"]
repository_id = query["FORGEJO_REPOSITORY_ID"]
req = urllib.request.Request(
    f"{host}/api/v1/repositories/{repository_id}",
    headers={"Authorization": f"token {token}", "Content-Type": "application/json"},
    method="GET",
)
with urllib.request.urlopen(req, timeout=30) as resp:
    payload = json.loads(resp.read().decode("utf-8"))

print(json.dumps({
    "owner": payload["owner"]["username"],
    "name": payload["name"],
    "default_branch": payload.get("default_branch", "main"),
}))
PY
  ]

  query = {
    FORGEJO_HOST          = data.external.forgejo_env.result.forgejo_host
    FORGEJO_API_TOKEN     = data.external.forgejo_env.result.forgejo_api_token
    FORGEJO_REPOSITORY_ID = tostring(var.repository_id)
  }
}

locals {
  repository_owner          = data.external.repository.result.owner
  repository_name           = data.external.repository.result.name
  repository_default_branch = data.external.repository.result.default_branch
}

resource "forgejo_repository_action_secret" "kubeconfig" {
  repository_id = var.repository_id
  name          = "KUBECONFIG${var.repository_secret_name_suffix}"
  data = yamlencode(merge(local.kubeconfig, {
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

resource "forgejo_repository_action_secret" "namespace" {
  repository_id = var.repository_id
  name          = "K8S_NAMESPACE${var.repository_secret_name_suffix}"
  data          = var.namespace
}

resource "restapi_object" "pipeline_dispatch" {
  path          = "/api/v1/repositories"
  id_attribute  = "id"
  object_id     = tostring(var.repository_id)
  create_path   = "/api/v1/repos/${local.repository_owner}/${local.repository_name}/actions/workflows/pipeline.yaml/dispatches"
  create_method = "POST"
  update_path   = "/api/v1/repos/${local.repository_owner}/${local.repository_name}/actions/workflows/pipeline.yaml/dispatches"
  update_method = "POST"
  data = jsonencode({
    ref = local.repository_default_branch
  })
  ignore_all_server_changes = true

  depends_on = [
    forgejo_repository_action_secret.kubeconfig,
    forgejo_repository_action_secret.namespace
  ]
}

resource "terraform_data" "await_pipeline_workflow" {
  depends_on = [restapi_object.pipeline_dispatch]

  provisioner "local-exec" {
    command = <<-EOT
      python3 - <<'PY'
import json
import os
import time
import urllib.request

host = os.environ["FORGEJO_HOST"].rstrip("/")
token = os.environ["FORGEJO_API_TOKEN"]
owner = os.environ["FORGEJO_REPOSITORY_OWNER"]
repo = os.environ["FORGEJO_REPOSITORY_NAME"]
branch = os.environ["FORGEJO_REPOSITORY_DEFAULT_BRANCH"]

runs_url = f"{host}/api/v1/repos/{owner}/{repo}/actions/runs?limit=20"
headers = {"Authorization": f"token {token}", "Content-Type": "application/json"}

def list_runs():
    req = urllib.request.Request(runs_url, headers=headers, method="GET")
    with urllib.request.urlopen(req, timeout=30) as resp:
        payload = json.loads(resp.read().decode("utf-8"))
    return payload.get("workflow_runs", [])

deadline = time.time() + 900
seen_run_id = None

while time.time() < deadline:
    runs = list_runs()
    candidates = [r for r in runs if r.get("event") == "workflow_dispatch" and r.get("head_branch") == branch]
    candidates.sort(key=lambda r: r.get("id", 0), reverse=True)

    if candidates:
        run = candidates[0]
        run_id = run.get("id")
        status = run.get("status")
        conclusion = run.get("conclusion")
        html_url = run.get("html_url", "")

        if seen_run_id is None:
            seen_run_id = run_id

        if run_id == seen_run_id and status == "completed":
            if conclusion == "success":
                print(f"Workflow run {run_id} completed successfully: {html_url}")
                raise SystemExit(0)
            raise SystemExit(f"Workflow run {run_id} failed with conclusion={conclusion}: {html_url}")

    time.sleep(10)

raise SystemExit("Timed out waiting for dispatched pipeline workflow to complete.")
PY
    EOT
    environment = {
      FORGEJO_HOST                      = data.external.forgejo_env.result.forgejo_host
      FORGEJO_API_TOKEN                 = data.external.forgejo_env.result.forgejo_api_token
      FORGEJO_REPOSITORY_OWNER          = local.repository_owner
      FORGEJO_REPOSITORY_NAME           = local.repository_name
      FORGEJO_REPOSITORY_DEFAULT_BRANCH = local.repository_default_branch
    }
  }
}
