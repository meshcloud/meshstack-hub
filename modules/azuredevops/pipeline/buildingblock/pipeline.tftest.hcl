variables {
  azure_devops_organization_url = "https://dev.azure.com/testorg"
  key_vault_name                = "kv-test-azdo"
  resource_group_name           = "rg-test-azdo"
}

run "valid_pipeline_configuration" {
  command = plan

  variables {
    project_id    = "12345678-1234-1234-1234-123456789012"
    pipeline_name = "test-pipeline"
    repository_id = "test-repo"
  }

  assert {
    condition     = azuredevops_build_definition.main.name == "test-pipeline"
    error_message = "Pipeline name should match input variable"
  }

  assert {
    condition     = azuredevops_build_definition.main.project_id == "12345678-1234-1234-1234-123456789012"
    error_message = "Pipeline should be created in the specified project"
  }

  assert {
    condition     = azuredevops_build_definition.main.repository[0].repo_id == "test-repo"
    error_message = "Pipeline should reference the correct repository"
  }
}

run "pipeline_with_custom_yaml_path" {
  command = plan

  variables {
    project_id    = "12345678-1234-1234-1234-123456789012"
    pipeline_name = "custom-pipeline"
    repository_id = "test-repo"
    yaml_path     = "ci/custom-pipeline.yml"
  }

  assert {
    condition     = azuredevops_build_definition.main.repository[0].yml_path == "ci/custom-pipeline.yml"
    error_message = "Pipeline should use custom YAML path"
  }
}

run "pipeline_with_custom_branch" {
  command = plan

  variables {
    project_id    = "12345678-1234-1234-1234-123456789012"
    pipeline_name = "develop-pipeline"
    repository_id = "test-repo"
    branch_name   = "refs/heads/develop"
  }

  assert {
    condition     = azuredevops_build_definition.main.repository[0].branch_name == "refs/heads/develop"
    error_message = "Pipeline should use custom branch"
  }
}

run "pipeline_with_variables" {
  command = plan

  variables {
    project_id    = "12345678-1234-1234-1234-123456789012"
    pipeline_name = "var-pipeline"
    repository_id = "test-repo"

    pipeline_variables = [
      {
        name  = "environment"
        value = "production"
      },
      {
        name      = "api_key"
        value     = "secret"
        is_secret = true
      }
    ]
  }

  assert {
    condition     = length(azuredevops_build_definition.main.variable) == 2
    error_message = "Pipeline should have 2 variables"
  }
}

run "pipeline_with_variable_groups" {
  command = plan

  variables {
    project_id    = "12345678-1234-1234-1234-123456789012"
    pipeline_name = "vg-pipeline"
    repository_id = "test-repo"

    variable_group_ids = [10, 20, 30]
  }

  assert {
    condition     = length(azuredevops_build_definition.main.variable_groups) == 3
    error_message = "Pipeline should link 3 variable groups"
  }
}

run "github_repository_pipeline" {
  command = plan

  variables {
    project_id      = "12345678-1234-1234-1234-123456789012"
    pipeline_name   = "github-pipeline"
    repository_type = "GitHub"
    repository_id   = "myorg/myrepo"
  }

  assert {
    condition     = azuredevops_build_definition.main.repository[0].repo_type == "GitHub"
    error_message = "Pipeline should use GitHub repository type"
  }

  assert {
    condition     = azuredevops_build_definition.main.repository[0].repo_id == "myorg/myrepo"
    error_message = "Pipeline should reference GitHub repository"
  }
}

run "tfsgit_repository_pipeline" {
  command = plan

  variables {
    project_id      = "12345678-1234-1234-1234-123456789012"
    pipeline_name   = "tfsgit-pipeline"
    repository_type = "TfsGit"
    repository_id   = "azure-repo"
  }

  assert {
    condition     = azuredevops_build_definition.main.repository[0].repo_type == "TfsGit"
    error_message = "Pipeline should use TfsGit repository type"
  }
}

run "invalid_repository_type" {
  command = plan

  variables {
    project_id      = "12345678-1234-1234-1234-123456789012"
    pipeline_name   = "test-pipeline"
    repository_id   = "test-repo"
    repository_type = "InvalidType"
  }

  expect_failures = [
    var.repository_type
  ]
}

run "pipeline_with_default_values" {
  command = plan

  variables {
    project_id    = "12345678-1234-1234-1234-123456789012"
    pipeline_name = "default-pipeline"
    repository_id = "test-repo"
  }

  assert {
    condition     = azuredevops_build_definition.main.repository[0].repo_type == "TfsGit"
    error_message = "Default repository type should be TfsGit"
  }

  assert {
    condition     = azuredevops_build_definition.main.repository[0].branch_name == "refs/heads/main"
    error_message = "Default branch should be refs/heads/main"
  }

  assert {
    condition     = azuredevops_build_definition.main.repository[0].yml_path == "azure-pipelines.yml"
    error_message = "Default YAML path should be azure-pipelines.yml"
  }
}

run "pipeline_with_empty_variable_groups" {
  command = plan

  variables {
    project_id         = "12345678-1234-1234-1234-123456789012"
    pipeline_name      = "no-vg-pipeline"
    repository_id      = "test-repo"
    variable_group_ids = []
  }

  assert {
    condition     = length(azuredevops_build_definition.main.variable_groups) == 0
    error_message = "Pipeline should have no variable groups"
  }
}
