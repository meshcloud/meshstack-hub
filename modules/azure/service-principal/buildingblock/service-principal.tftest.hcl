variables {
  display_name          = "test-service-principal"
  azure_subscription_id = "f808fff2-adda-415a-9b77-2833c041aacf"
}

run "valid_contributor_service_principal" {
  variables {
    display_name = "test-sp-contributor"
    azure_role   = "Contributor"
    description  = "Test service principal with Contributor role"
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
  variables {
    display_name = "test-sp-reader"
    azure_role   = "Reader"
  }

  assert {
    condition     = azurerm_role_assignment.main.role_definition_name == "Reader"
    error_message = "Role assignment should be Reader"
  }
}

run "valid_owner_service_principal" {
  variables {
    display_name = "test-sp-owner"
    azure_role   = "Owner"
  }

  assert {
    condition     = azurerm_role_assignment.main.role_definition_name == "Owner"
    error_message = "Role assignment should be Owner"
  }
}

run "invalid_role_validation" {
  variables {
    display_name = "test-sp-invalid"
    azure_role   = "CustomRole"
  }

  expect_failures = [
    var.azure_role
  ]
}

run "custom_secret_rotation" {
  variables {
    display_name         = "test-sp-rotation"
    secret_rotation_days = 180
    create_client_secret = true
  }

  assert {
    condition     = time_rotating.secret_rotation[0].rotation_days == 180
    error_message = "Secret rotation should be 180 days"
  }
}

run "invalid_secret_rotation_too_short" {
  variables {
    display_name         = "test-sp-short-rotation"
    secret_rotation_days = 15
  }

  expect_failures = [
    var.secret_rotation_days
  ]
}

run "invalid_secret_rotation_too_long" {

  variables {
    display_name         = "test-sp-long-rotation"
    secret_rotation_days = 800
  }

  expect_failures = [
    var.secret_rotation_days
  ]
}

run "custom_description" {

  variables {
    display_name = "test-sp-description"
    description  = "Custom service principal for CI/CD pipelines"
  }

  assert {
    condition     = azuread_application.main.description == "Custom service principal for CI/CD pipelines"
    error_message = "Application description should match input"
  }
}

run "service_principal_without_secret" {

  variables {
    display_name         = "test-sp-oidc"
    create_client_secret = false
    description          = "Service principal for OIDC authentication"
  }

  assert {
    condition     = azuread_application.main.display_name == "test-sp-oidc"
    error_message = "Application display name should match input"
  }

  assert {
    condition     = output.client_secret == null
    error_message = "Client secret should be null when create_client_secret is false"
  }

  assert {
    condition     = output.secret_expiration_date == null
    error_message = "Secret expiration date should be null when create_client_secret is false"
  }

  assert {
    condition     = output.authentication_method == "workload_identity_federation"
    error_message = "Authentication method should be workload_identity_federation"
  }
}
