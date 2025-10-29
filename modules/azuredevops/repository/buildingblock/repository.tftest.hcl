variables {
  azure_devops_organization_url = "https://dev.azure.com/testorg"
  key_vault_name                = "kv-test-azdo"
  resource_group_name           = "rg-test-azdo"
}

run "valid_repository_configuration" {
  command = plan

  variables {
    project_id      = "12345678-1234-1234-1234-123456789012"
    repository_name = "test-repository"
  }

  assert {
    condition     = azuredevops_git_repository.main.name == "test-repository"
    error_message = "Repository name should match input variable"
  }

  assert {
    condition     = azuredevops_git_repository.main.project_id == "12345678-1234-1234-1234-123456789012"
    error_message = "Repository should be created in the specified project"
  }
}

run "repository_with_branch_policies" {
  command = plan

  variables {
    project_id             = "12345678-1234-1234-1234-123456789012"
    repository_name        = "protected-repo"
    enable_branch_policies = true
    minimum_reviewers      = 3
  }

  assert {
    condition     = var.enable_branch_policies == true
    error_message = "Branch policies should be enabled"
  }

  assert {
    condition     = var.minimum_reviewers == 3
    error_message = "Minimum reviewers should be 3"
  }

  assert {
    condition     = length(azuredevops_branch_policy_min_reviewers.main) == 1
    error_message = "Branch policy should be created when enabled"
  }
}

run "repository_without_branch_policies" {
  command = plan

  variables {
    project_id             = "12345678-1234-1234-1234-123456789012"
    repository_name        = "unprotected-repo"
    enable_branch_policies = false
  }

  assert {
    condition     = var.enable_branch_policies == false
    error_message = "Branch policies should be disabled"
  }

  assert {
    condition     = length(azuredevops_branch_policy_min_reviewers.main) == 0
    error_message = "No branch policy should be created when disabled"
  }
}

run "uninitialized_repository" {
  command = plan

  variables {
    project_id      = "12345678-1234-1234-1234-123456789012"
    repository_name = "empty-repo"
    init_type       = "Uninitialized"
  }

  assert {
    condition     = azuredevops_git_repository.main.initialization[0].init_type == "Uninitialized"
    error_message = "Repository initialization type should be Uninitialized"
  }
}

run "clean_initialization" {
  command = plan

  variables {
    project_id      = "12345678-1234-1234-1234-123456789012"
    repository_name = "new-repo"
    init_type       = "Clean"
  }

  assert {
    condition     = azuredevops_git_repository.main.initialization[0].init_type == "Clean"
    error_message = "Repository initialization type should be Clean"
  }
}

run "invalid_init_type" {
  command = plan

  variables {
    project_id      = "12345678-1234-1234-1234-123456789012"
    repository_name = "test-repo"
    init_type       = "Invalid"
  }

  expect_failures = [
    var.init_type
  ]
}

run "minimum_reviewers_out_of_range" {
  command = plan

  variables {
    project_id        = "12345678-1234-1234-1234-123456789012"
    repository_name   = "test-repo"
    minimum_reviewers = 15
  }

  expect_failures = [
    var.minimum_reviewers
  ]
}

run "minimum_reviewers_zero" {
  command = plan

  variables {
    project_id        = "12345678-1234-1234-1234-123456789012"
    repository_name   = "test-repo"
    minimum_reviewers = 0
  }

  expect_failures = [
    var.minimum_reviewers
  ]
}
