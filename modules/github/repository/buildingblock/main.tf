# Data source to check if repository exists
data "github_repository" "existing" {
  count = var.allow_using_existing_repo ? 1 : 0
  name  = var.repo_name
}

locals {
  # Determine if we are using an existing repository or creating a new one
  use_existing_repo = length(data.github_repository.existing) > 0 && try(data.github_repository.existing[0].name, null) != null && var.allow_using_existing_repo && length(github_repository.repository) == 0

  # Archived repositories are read-only, so this check is important if we want to add collaborators
  repo_is_archived = local.use_existing_repo ? try(data.github_repository.existing[0].archived, false) : try(github_repository.repository[0].archived, false)
}

moved {
  from = github_repository.repository
  to   = github_repository.repository[0]
}

resource "github_repository" "repository" {
  # If the repository exists, we don't create a new one
  count                = local.use_existing_repo ? 0 : 1
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
  # Only add the collaborator if the repository is not archived and the repo_owner is set
  count      = var.repo_owner != null && var.repo_owner != "null" && (local.repo_is_archived != true) ? 1 : 0 # We have to check for 'null' string as optional inputs are not possible atm
  repository = var.repo_name
  username   = var.repo_owner
  permission = "admin"

  depends_on = [data.github_repository.existing, github_repository.repository]
}
