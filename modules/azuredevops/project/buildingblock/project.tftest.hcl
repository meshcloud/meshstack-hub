
variables {
  azure_devops_organization_url = "https://dev.azure.com/meshcloud-prod"
  key_vault_name                = "ado-demo"
  resource_group_name           = "rg-devops"
  pat_secret_name               = "ado-pat"
}

run "valid_project_creation" {
  command = plan
  variables {
    project_name        = "test-project"
    project_description = "Test project for validation"
    users = [
      {
        meshIdentifier = "likvid-tom-user"
        username       = "likvid-tom@meshcloud.io"
        firstName      = "Tom"
        lastName       = "Livkid"
        email          = "likvid-tom@meshcloud.io"
        euid           = "likvid-tom@meshcloud.io"
        roles          = ["admin", "Workspace Owner"]
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
    project_name = "test-project"
    users = [
      {
        meshIdentifier = "likvid-anna-user"
        username       = "likvid-anna@meshcloud.io"
        firstName      = "Anna"
        lastName       = "Livkid"
        email          = "likvid-anna@meshcloud.io"
        euid           = "likvid-anna@meshcloud.io"
        roles          = ["reader", "Workspace Member"]
      },
      {
        meshIdentifier = "likvid-daniela-user"
        username       = "likvid-daniela@meshcloud.io"
        firstName      = "Daniela"
        lastName       = "Livkid"
        email          = "likvid-daniela@meshcloud.io"
        euid           = "likvid-daniela@meshcloud.io"
        roles          = ["user", "Workspace Manager"]
      },
      {
        meshIdentifier = "likvid-tom-user"
        username       = "likvid-tom@meshcloud.io"
        firstName      = "Tom"
        lastName       = "Livkid"
        email          = "likvid-tom@meshcloud.io"
        euid           = "likvid-tom@meshcloud.io"
        roles          = ["admin", "Workspace Owner"]
      }
    ]
  }

  assert {
    condition     = length(local.readers) == 1
    error_message = "Should identify one user with reader role"
  }

  assert {
    condition     = length(local.contributors) == 1
    error_message = "Should identify one user with user role"
  }

  assert {
    condition     = length(local.administrators) == 1
    error_message = "Should identify one user with admin role"
  }
}

run "invalid_project_name_empty" {
  command = plan
  expect_failures = [
    var.project_name
  ]

  variables {
    project_name = ""
    users = [
      {
        meshIdentifier = "likvid-tom-user"
        username       = "likvid-tom@meshcloud.io"
        firstName      = "Tom"
        lastName       = "Livkid"
        email          = "likvid-tom@meshcloud.io"
        euid           = "likvid-tom@meshcloud.io"
        roles          = ["admin", "Workspace Owner"]
      }
    ]
  }
}

run "invalid_project_name_too_long" {
  command = plan
  expect_failures = [
    var.project_name
  ]

  variables {
    azure_devops_organization_url = "https://dev.azure.com/meshcloud-prod"
    key_vault_name                = "ado-demo"
    resource_group_name           = "rg-devops"
    project_name                  = "ThisProjectNameIsWayTooLongAndExceedsTheMaximumAllowedCharacterLimitOf64Characters"
    pat_secret_name               = "ado-pat"
    users = [
      {
        meshIdentifier = "likvid-tom-user"
        username       = "likvid-tom@meshcloud.io"
        firstName      = "Tom"
        lastName       = "Livkid"
        email          = "likvid-tom@meshcloud.io"
        euid           = "likvid-tom@meshcloud.io"
        roles          = ["admin", "Workspace Owner"]
      }
    ]
  }
}

run "user_with_multiple_roles" {
  command = plan

  variables {
    azure_devops_organization_url = "https://dev.azure.com/meshcloud-prod"
    key_vault_name                = "ado-demo"
    resource_group_name           = "rg-devops"
    project_name                  = "test-project"
    pat_secret_name               = "ado-pat"

    users = [
      {
        meshIdentifier = "likvid-tom-user"
        username       = "likvid-tom@meshcloud.io"
        firstName      = "Tom"
        lastName       = "Livkid"
        email          = "likvid-tom@meshcloud.io"
        euid           = "likvid-tom@meshcloud.io"
        roles          = ["admin", "reader", "user", "Workspace Owner"] # Multiple roles
      }
    ]
  }

  assert {
    condition     = length(local.readers) == 1
    error_message = "User with multiple roles should be in readers group"
  }

  assert {
    condition     = length(local.contributors) == 1
    error_message = "User with multiple roles should be in contributors group"
  }

  assert {
    condition     = length(local.administrators) == 1
    error_message = "User with multiple roles should be in administrators group"
  }
}

run "user_without_relevant_roles" {
  command = plan

  variables {
    azure_devops_organization_url = "https://dev.azure.com/meshcloud-prod"
    key_vault_name                = "ado-demo"
    resource_group_name           = "rg-devops"
    project_name                  = "test-project"
    pat_secret_name               = "ado-pat"
    users = [
      {
        meshIdentifier = "likvid-daniela-user"
        username       = "likvid-daniela@meshcloud.io"
        firstName      = "Daniela"
        lastName       = "Livkid"
        email          = "likvid-daniela@meshcloud.io"
        euid           = "likvid-daniela@meshcloud.io"
        roles          = ["NONE Exisiting Role"] # No Azure DevOps relevant roles
      }
    ]
  }

  assert {
    condition     = length(local.readers) == 0
    error_message = "User without reader role should not be in readers group"
  }

  assert {
    condition     = length(local.contributors) == 0
    error_message = "User without user role should not be in contributors group"
  }

  assert {
    condition     = length(local.administrators) == 0
    error_message = "User without admin role should not be in administrators group"
  }
}

run "default_project_features" {
  command = plan

  variables {
    azure_devops_organization_url = "https://dev.azure.com/meshcloud-prod"
    key_vault_name                = "ado-demo"
    resource_group_name           = "rg-devops"
    project_name                  = "test-project"
    pat_secret_name               = "ado-pat"
    users = [
      {
        meshIdentifier = "likvid-tom-user"
        username       = "likvid-tom@meshcloud.io"
        firstName      = "Tom"
        lastName       = "Livkid"
        email          = "likvid-tom@meshcloud.io"
        euid           = "likvid-tom@meshcloud.io"
        roles          = ["admin", "Workspace Owner"]
      }
    ]
  }

  assert {
    condition     = azuredevops_project.main.features.boards == "enabled"
    error_message = "Boards should be enabled by default"
  }

  assert {
    condition     = azuredevops_project.main.features.repositories == "enabled"
    error_message = "Repositories should be enabled by default"
  }

  assert {
    condition     = azuredevops_project.main.features.pipelines == "enabled"
    error_message = "Pipelines should be enabled by default"
  }

  assert {
    condition     = azuredevops_project.main.features.testplans == "disabled"
    error_message = "Test plans should be disabled by default"
  }

  assert {
    condition     = azuredevops_project.main.features.artifacts == "enabled"
    error_message = "Artifacts should be enabled by default"
  }
}

