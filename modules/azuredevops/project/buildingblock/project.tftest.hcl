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
        principal_name = "test.user@example.com"
        role          = "contributor"
        license_type  = "stakeholder"
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

run "user_entitlement_validation" {
  command = plan

  variables {
    azure_devops_organization_url = "https://dev.azure.com/testorg"
    key_vault_name               = "kv-test-devops"
    resource_group_name          = "rg-test-devops"
    project_name                = "test-project"
    
    users = [
      {
        principal_name = "stakeholder@example.com"
        role          = "reader"
        license_type  = "stakeholder"
      },
      {
        principal_name = "developer@example.com"
        role          = "contributor"
        license_type  = "basic"
      },
      {
        principal_name = "admin@example.com"
        role          = "administrator"
        license_type  = "advanced"
      }
    ]
  }

  assert {
    condition = length([
      for user in azuredevops_user_entitlement.users : user
      if user.account_license_type == "stakeholder"
    ]) == 1
    error_message = "Should create one user with stakeholder license"
  }

  assert {
    condition = length([
      for user in azuredevops_user_entitlement.users : user
      if user.account_license_type == "basic"
    ]) == 1
    error_message = "Should create one user with basic license"
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

run "invalid_user_role" {
  command = plan
  expect_failures = [
    var.users
  ]

  variables {
    azure_devops_organization_url = "https://dev.azure.com/testorg"
    key_vault_name               = "kv-test-devops"
    resource_group_name          = "rg-test-devops"
    project_name                = "test-project"
    
    users = [
      {
        principal_name = "test@example.com"
        role          = "invalid-role"  # Invalid role
        license_type  = "stakeholder"
      }
    ]
  }
}

run "invalid_license_type" {
  command = plan
  expect_failures = [
    var.users
  ]

  variables {
    azure_devops_organization_url = "https://dev.azure.com/testorg"
    key_vault_name               = "kv-test-devops"
    resource_group_name          = "rg-test-devops"
    project_name                = "test-project"
    
    users = [
      {
        principal_name = "test@example.com"
        role          = "contributor"
        license_type  = "invalid-license"  # Invalid license type
      }
    ]
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

run "custom_groups_creation" {
  command = plan

  variables {
    azure_devops_organization_url = "https://dev.azure.com/testorg"
    key_vault_name               = "kv-test-devops"
    resource_group_name          = "rg-test-devops"
    project_name                = "test-project"
    create_custom_groups         = true
  }

  assert {
    condition     = length(azuredevops_group.custom_readers) == 1
    error_message = "Should create custom readers group when enabled"
  }

  assert {
    condition     = length(azuredevops_group.custom_contributors) == 1
    error_message = "Should create custom contributors group when enabled"
  }

  assert {
    condition     = length(azuredevops_group.custom_administrators) == 1
    error_message = "Should create custom administrators group when enabled"
  }
}

run "no_custom_groups" {
  command = plan

  variables {
    azure_devops_organization_url = "https://dev.azure.com/testorg"
    key_vault_name               = "kv-test-devops"
    resource_group_name          = "rg-test-devops"
    project_name                = "test-project"
    create_custom_groups         = false
  }

  assert {
    condition     = length(azuredevops_group.custom_readers) == 0
    error_message = "Should not create custom readers group when disabled"
  }

  assert {
    condition     = length(azuredevops_group.custom_contributors) == 0
    error_message = "Should not create custom contributors group when disabled"
  }

  assert {
    condition     = length(azuredevops_group.custom_administrators) == 0
    error_message = "Should not create custom administrators group when disabled"
  }
}