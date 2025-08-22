# Data source to check if repository exists
data "github_repository" "existing" {
  name = var.repo_name
}

moved {
  from = github_repository.repository
  to   = github_repository.repository[0]
}

resource "github_repository" "repository" {
  # If the repository exists, we don't create a new one
  count                = data.github_repository.existing.name != null ? 0 : 1
  name                 = var.repo_name
  description          = var.repo_description
  visibility           = var.repo_visibility
  auto_init            = false
  vulnerability_alerts = true
  archive_on_destroy   = true

  dynamic "template" {
    for_each = var.use_template ? [1] : []
    content {
      owner                = var.template_owner
      repository           = var.template_repo
      include_all_branches = true
    }
  }
}

resource "github_repository_collaborator" "repo_owner" {
  count      = var.repo_owner != null && var.repo_owner != "null" ? 1 : 0 # We have to check for 'null' string as optional inputs are not possible atm
  repository = var.repo_name
  username   = var.repo_owner
  permission = "admin"

  depends_on = [data.github_repository.existing, github_repository.repository]
}
