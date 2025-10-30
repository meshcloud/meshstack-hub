variables {
  azure_devops_organization_url = "https://dev.azure.com/meshcloud-prod"
  key_vault_name                = "ado-demo"
  resource_group_name           = "rg-devops"
  pat_secret_name               = "ado-pat"
  project_id                    = "eece6ccc-c821-46a1-9214-80df6da9e13f"
  repository_name               = "test-repo"
}

run "valid_repository_configuration" {
  command = plan

  variables {
  }

  assert {
    condition     = azuredevops_git_repository.main.name == "test-repo"
    error_message = "Repository name should match input variable"
  }

  assert {
    condition     = azuredevops_git_repository.main.project_id == "eece6ccc-c821-46a1-9214-80df6da9e13f"
    error_message = "Repository should be created in the specified project"
  }
}

run "repository_with_branch_policies" {
  command = plan

  variables {
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
    init_type = "Uninitialized"
  }

  assert {
    condition     = azuredevops_git_repository.main.initialization[0].init_type == "Uninitialized"
    error_message = "Repository initialization type should be Uninitialized"
  }
}

run "clean_initialization" {
  command = plan

  variables {
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
    init_type = "Invalid"
  }

  expect_failures = [
    var.init_type
  ]
}

run "minimum_reviewers_out_of_range" {
  command = plan

  variables {
    minimum_reviewers = 15
  }

  expect_failures = [
    var.minimum_reviewers
  ]
}

run "minimum_reviewers_zero" {
  command = plan

  variables {
    minimum_reviewers = 0
  }

  expect_failures = [
    var.minimum_reviewers
  ]
}
