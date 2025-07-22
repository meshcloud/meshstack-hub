resource "github_repository" "repository" {
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
  count      = var.repo_owner != null ? 1 : 0
  repository = github_repository.repository.name
  username   = var.repo_owner
  permission = "admin"
}
