variables {
  display_name          = "test-service-principal"
  azure_subscription_id = "12345678-1234-1234-1234-123456789012"
}

run "valid_contributor_service_principal" {
  command = plan

  variables {
    display_name          = "test-sp-contributor"
    azure_subscription_id = "12345678-1234-1234-1234-123456789012"
    azure_role            = "Contributor"
    description           = "Test service principal with Contributor role"
  }

  assert {
    condition     = azuread_application.main.display_name == "test-sp-contributor"
    error_message = "Application display name should match input"
  }

  assert {
    condition     = azurerm_role_assignment.main.role_definition_name == "Contributor"
    error_message = "Role assignment should be Contributor"
  }
}

run "valid_reader_service_principal" {
  command = plan

  variables {
    display_name          = "test-sp-reader"
    azure_subscription_id = "12345678-1234-1234-1234-123456789012"
    azure_role            = "Reader"
  }

  assert {
    condition     = azurerm_role_assignment.main.role_definition_name == "Reader"
    error_message = "Role assignment should be Reader"
  }
}

run "valid_owner_service_principal" {
  command = plan

  variables {
    display_name          = "test-sp-owner"
    azure_subscription_id = "12345678-1234-1234-1234-123456789012"
    azure_role            = "Owner"
  }

  assert {
    condition     = azurerm_role_assignment.main.role_definition_name == "Owner"
    error_message = "Role assignment should be Owner"
  }
}

run "invalid_role_validation" {
  command = plan

  variables {
    display_name          = "test-sp-invalid"
    azure_subscription_id = "12345678-1234-1234-1234-123456789012"
    azure_role            = "CustomRole"
  }

  expect_failures = [
    var.azure_role
  ]
}

run "custom_secret_rotation" {
  command = plan

  variables {
    display_name          = "test-sp-rotation"
    azure_subscription_id = "12345678-1234-1234-1234-123456789012"
    secret_rotation_days  = 180
  }

  assert {
    condition     = time_rotating.secret_rotation.rotation_days == 180
    error_message = "Secret rotation should be 180 days"
  }
}

run "invalid_secret_rotation_too_short" {
  command = plan

  variables {
    display_name          = "test-sp-short-rotation"
    azure_subscription_id = "12345678-1234-1234-1234-123456789012"
    secret_rotation_days  = 15
  }

  expect_failures = [
    var.secret_rotation_days
  ]
}

run "invalid_secret_rotation_too_long" {
  command = plan

  variables {
    display_name          = "test-sp-long-rotation"
    azure_subscription_id = "12345678-1234-1234-1234-123456789012"
    secret_rotation_days  = 800
  }

  expect_failures = [
    var.secret_rotation_days
  ]
}

run "custom_description" {
  command = plan

  variables {
    display_name          = "test-sp-description"
    azure_subscription_id = "12345678-1234-1234-1234-123456789012"
    description           = "Custom service principal for CI/CD pipelines"
  }

  assert {
    condition     = azuread_application.main.description == "Custom service principal for CI/CD pipelines"
    error_message = "Application description should match input"
  }
}
