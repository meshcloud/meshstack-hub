run "valid_project_creation" {
  command = plan

  variables {
    azure_devops_organization_url = "https://dev.azure.com/testorg"
    key_vault_name               = "kv-test-devops"
    resource_group_name          = "rg-test-devops"
    project_name                = "test-project"
    project_description         = "Test project for validation"
    
    users = [
      {
        meshIdentifier = "test-user-001"
        username       = "testuser"
        firstName      = "Test"
        lastName       = "User"
        email          = "test.user@example.com"
        euid           = "test.user"
        roles          = ["user"]
      }
    ]
  }

  assert {
    condition     = azuredevops_project.main.name == "test-project"
    error_message = "Project name should match input variable"
  }

  assert {
    condition     = azuredevops_project.main.visibility == "private"
    error_message = "Project should default to private visibility"
  }

  assert {
    condition     = azuredevops_project.main.work_item_template == "Agile"
    error_message = "Project should default to Agile work item template"
  }
}

run "user_role_assignment_validation" {
  command = plan

  variables {
    azure_devops_organization_url = "https://dev.azure.com/testorg"
    key_vault_name               = "kv-test-devops"
    resource_group_name          = "rg-test-devops"
    project_name                = "test-project"

    users = [
      {
        meshIdentifier = "reader-001"
        username       = "readeruser"
        firstName      = "Reader"
        lastName       = "User"
        email          = "reader@example.com"
        euid           = "reader.user"
        roles          = ["reader"]
      },
      {
        meshIdentifier = "dev-001"
        username       = "developer"
        firstName      = "Dev"
        lastName       = "User"
        email          = "developer@example.com"
        euid           = "dev.user"
        roles          = ["user"]
      },
      {
        meshIdentifier = "admin-001"
        username       = "adminuser"
        firstName      = "Admin"
        lastName       = "User"
        email          = "admin@example.com"
        euid           = "admin.user"
        roles          = ["admin"]
      }
    ]
  }

  assert {
    condition = length(local.readers) == 1
    error_message = "Should identify one user with reader role"
  }

  assert {
    condition = length(local.contributors) == 1
    error_message = "Should identify one user with user role"
  }

  assert {
    condition = length(local.administrators) == 1
    error_message = "Should identify one user with admin role"
  }
}

run "invalid_project_name" {
  command = plan
  expect_failures = [
    var.project_name
  ]

  variables {
    azure_devops_organization_url = "https://dev.azure.com/testorg"
    key_vault_name               = "kv-test-devops"
    resource_group_name          = "rg-test-devops"
    project_name                = ""  # Invalid: empty name
  }
}

run "user_with_multiple_roles" {
  command = plan

  variables {
    azure_devops_organization_url = "https://dev.azure.com/testorg"
    key_vault_name               = "kv-test-devops"
    resource_group_name          = "rg-test-devops"
    project_name                = "test-project"

    users = [
      {
        meshIdentifier = "multi-001"
        username       = "multiuser"
        firstName      = "Multi"
        lastName       = "User"
        email          = "multi@example.com"
        euid           = "multi.user"
        roles          = ["admin", "reader", "user"]  # Multiple roles
      }
    ]
  }

  assert {
    condition = length(local.readers) == 1
    error_message = "User with multiple roles should be in readers group"
  }

  assert {
    condition = length(local.contributors) == 1
    error_message = "User with multiple roles should be in contributors group"
  }

  assert {
    condition = length(local.administrators) == 1
    error_message = "User with multiple roles should be in administrators group"
  }
}

run "user_without_relevant_roles" {
  command = plan

  variables {
    azure_devops_organization_url = "https://dev.azure.com/testorg"
    key_vault_name               = "kv-test-devops"
    resource_group_name          = "rg-test-devops"
    project_name                = "test-project"

    users = [
      {
        meshIdentifier = "norole-001"
        username       = "noroleuser"
        firstName      = "No"
        lastName       = "Role"
        email          = "norole@example.com"
        euid           = "no.role"
        roles          = ["some-other-role"]  # No Azure DevOps relevant roles
      }
    ]
  }

  assert {
    condition = length(local.readers) == 0
    error_message = "User without reader role should not be in readers group"
  }

  assert {
    condition = length(local.contributors) == 0
    error_message = "User without user role should not be in contributors group"
  }

  assert {
    condition = length(local.administrators) == 0
    error_message = "User without admin role should not be in administrators group"
  }
}

run "project_features_configuration" {
  command = plan

  variables {
    azure_devops_organization_url = "https://dev.azure.com/testorg"
    key_vault_name               = "kv-test-devops"
    resource_group_name          = "rg-test-devops"
    project_name                = "test-project"
    
    project_features = {
      boards      = "enabled"
      repositories = "enabled"
      pipelines   = "enabled"
      testplans   = "disabled"
      artifacts   = "disabled"
    }
  }

  assert {
    condition     = azuredevops_project.main.features.testplans == "disabled"
    error_message = "Test plans should be disabled"
  }

  assert {
    condition     = azuredevops_project.main.features.artifacts == "disabled"
    error_message = "Artifacts should be disabled"
  }
}

