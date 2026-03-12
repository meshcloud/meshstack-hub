# ── Repository ─────────────────────────────────────────────────────────────────

resource "restapi_object" "repository" {
  path         = "/api/v1/repos"
  id_attribute = "full_name"
  object_id    = "${var.forgejo_organization}/${var.name}"
  create_path  = var.use_template ? "/api/v1/repos/${var.template_repo_path}/generate" : "/api/v1/orgs/${var.forgejo_organization}/repos"
  data = jsonencode(merge({
    owner       = var.forgejo_organization
    name        = var.name
    description = var.description
    private     = var.private
    },
    var.use_template ? {
      git_content = true
      git_hooks   = false
      } : {
      # Keep non-template repositories empty (no README/init commit).
      auto_init = false
    }
  ))
  read_path    = "/api/v1/repos/${var.forgejo_organization}/${var.name}"
  destroy_path = "/api/v1/repos/${var.forgejo_organization}/${var.name}"
  force_new    = ["data"]
}

# ── Webhook ────────────────────────────────────────────────────────────────────

resource "restapi_object" "webhook" {
  count = var.webhook_url != "" ? 1 : 0

  path         = "/api/v1/repos/${var.forgejo_organization}/${var.name}/hooks"
  id_attribute = "id"
  data = jsonencode({
    type = "forgejo"
    config = {
      url          = var.webhook_url
      content_type = "json"
      secret       = var.webhook_secret
    }
    events = var.webhook_events
    active = true
  })
  force_new = ["data"]

  depends_on = [restapi_object.repository]
}
