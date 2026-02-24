locals {
  owner = var.gitea_organization

  clone_url = "${var.gitea_base_url}/${local.owner}/${var.repository_name}.git"
  html_url  = "${var.gitea_base_url}/${local.owner}/${var.repository_name}"
  ssh_url   = "git@${replace(var.gitea_base_url, "https://", "")}:${local.owner}/${var.repository_name}.git"

  template_variables = {
    REPO_NAME = var.template_repo_name != "" ? var.template_repo_name : var.repository_name
    NAMESPACE = var.template_namespace != "" ? var.template_namespace : var.repository_name
    CLONE_URL = local.clone_url
  }
}

# ── Repository (empty, non-template) ──────────────────────────────────────────

resource "gitea_repository" "repo" {
  count = var.use_template ? 0 : 1

  username       = local.owner
  name           = var.repository_name
  description    = var.repository_description
  private        = var.repository_private
  auto_init      = var.repository_auto_init
  default_branch = var.default_branch
}

# ── Repository (from template, via Forgejo API) ───────────────────────────────

resource "null_resource" "template_repo" {
  count = var.use_template ? 1 : 0

  triggers = {
    repo_name      = var.repository_name
    owner          = local.owner
    template_owner = var.template_owner
    template_name  = var.template_name
    template_vars  = jsonencode(local.template_variables)
  }

  provisioner "local-exec" {
    command = <<-EOT
      response=$(curl -s -w "\n%\{http_code\}" \
        -X POST "${var.gitea_base_url}/api/v1/repos/${var.template_owner}/${var.template_name}/generate" \
        -H "Authorization: token ${var.gitea_token}" \
        -H "Content-Type: application/json" \
        -d '{
          "owner": "${local.owner}",
          "name": "${var.repository_name}",
          "description": "${var.repository_description}",
          "private": ${var.repository_private},
          "git_content": true,
          "git_hooks": false
        }')

      http_code=$(echo "$response" | tail -n1)
      body=$(echo "$response" | sed '$d')

      if [ "$http_code" -ge 200 ] && [ "$http_code" -lt 300 ]; then
        echo "Repository '${var.repository_name}' created from template '${var.template_owner}/${var.template_name}'"
      else
        echo "Failed to create repository from template. HTTP $http_code"
        echo "$body"
        exit 1
      fi
    EOT
  }
}

# ── Webhook ────────────────────────────────────────────────────────────────────

resource "null_resource" "webhook" {
  count = var.webhook_url != "" ? 1 : 0

  triggers = {
    webhook_url    = var.webhook_url
    webhook_secret = sha256(var.webhook_secret)
    webhook_events = join(",", var.webhook_events)
    repo           = "${local.owner}/${var.repository_name}"
  }

  provisioner "local-exec" {
    command = <<-EOT
      curl -s -X POST "${var.gitea_base_url}/api/v1/repos/${local.owner}/${var.repository_name}/hooks" \
        -H "Authorization: token ${var.gitea_token}" \
        -H "Content-Type: application/json" \
        -d '{
          "type": "forgejo",
          "config": {
            "url": "${var.webhook_url}",
            "content_type": "json",
            "secret": "${var.webhook_secret}"
          },
          "events": ${jsonencode(var.webhook_events)},
          "active": true
        }'
    EOT
  }

  depends_on = [gitea_repository.repo, null_resource.template_repo]
}
