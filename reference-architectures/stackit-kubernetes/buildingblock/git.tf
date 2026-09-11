# STACKIT Git (Forgejo) instance hosting the application repositories.
resource "stackit_git" "this" {
  project_id = local.stackit_project_id
  name       = var.git_instance_name
}

# The Forgejo organization repositories live under. Created via the REST API rather than the gitea
# provider, which refreshes unreliably against STACKIT Git (spurious 403s on plan). PATCH as the
# update method so re-applies converge instead of failing on an existing org.
resource "restapi_object" "forgejo_organization" {
  # Gated until the bot token is provided (see local.forgejo_enabled). The restapi provider needs the
  # token to authenticate, which only exists after a first run created the git instance.
  lifecycle {
    enabled = local.forgejo_enabled
  }

  path          = "/api/v1/orgs"
  id_attribute  = "username"
  object_id     = var.forgejo_organization
  update_method = "PATCH"

  data = jsonencode({
    username   = var.forgejo_organization
    visibility = "private"
  })

  ignore_server_additions = true

  depends_on = [stackit_git.this]
}

locals {
  # The real instance URL, handed to the starterkit modules. (The restapi provider uses a constructed
  # URL instead — see provider.tf for why.)
  forgejo_base_url = stackit_git.this.url
}
