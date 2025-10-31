data "azurerm_key_vault" "devops" {
  name                = var.key_vault_name
  resource_group_name = var.resource_group_name
}

data "azurerm_key_vault_secret" "azure_devops_pat" {
  name         = var.pat_secret_name
  key_vault_id = data.azurerm_key_vault.devops.id
}

resource "azuredevops_git_repository" "main" {
  project_id = var.project_id
  name       = var.repository_name

  initialization {
    init_type = var.init_type
  }

  lifecycle {
    ignore_changes = [
      initialization
    ]
  }
}

resource "azuredevops_branch_policy_min_reviewers" "main" {
  count = var.enable_branch_policies ? 1 : 0

  project_id = var.project_id

  enabled  = true
  blocking = true

  settings {
    reviewer_count                         = var.minimum_reviewers
    submitter_can_vote                     = false
    last_pusher_cannot_approve             = true
    allow_completion_with_rejects_or_waits = false
    on_push_reset_approved_votes           = true

    scope {
      repository_id  = azuredevops_git_repository.main.id
      repository_ref = azuredevops_git_repository.main.default_branch
      match_type     = "Exact"
    }
  }
}

resource "azuredevops_branch_policy_work_item_linking" "main" {
  count = var.enable_branch_policies ? 1 : 0

  project_id = var.project_id

  enabled  = true
  blocking = false

  settings {
    scope {
      repository_id  = azuredevops_git_repository.main.id
      repository_ref = azuredevops_git_repository.main.default_branch
      match_type     = "Exact"
    }
  }
}
