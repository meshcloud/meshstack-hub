# Mocked so the file actually runs: without these the providers reach for real Azure credentials and
# every run errors out before reaching an assertion. The azuread and azurerm providers validate
# object and role definition IDs even when mocked, so the defaults below have to be well-formed.
mock_provider "azuread" {
  mock_resource "azuread_application" {
    defaults = {
      id        = "/applications/11111111-1111-1111-1111-111111111112"
      client_id = "11111111-1111-1111-1111-111111111111"
      object_id = "11111111-1111-1111-1111-111111111112"
    }
  }

  mock_resource "azuread_service_principal" {
    defaults = {
      object_id = "11111111-1111-1111-1111-111111111113"
    }
  }
}

mock_provider "azurerm" {
  mock_data "azurerm_client_config" {
    defaults = {
      client_id       = "22222222-2222-2222-2222-222222222221"
      object_id       = "22222222-2222-2222-2222-222222222222"
      tenant_id       = "22222222-2222-2222-2222-222222222223"
      subscription_id = "f808fff2-adda-415a-9b77-2833c041aacf"
    }
  }

  mock_data "azurerm_subscription" {
    defaults = {
      id           = "/subscriptions/f808fff2-adda-415a-9b77-2833c041aacf"
      display_name = "mock-subscription"
      tenant_id    = "22222222-2222-2222-2222-222222222223"
    }
  }

  mock_resource "azurerm_role_definition" {
    defaults = {
      role_definition_id          = "33333333-3333-3333-3333-333333333333"
      role_definition_resource_id = "/subscriptions/f808fff2-adda-415a-9b77-2833c041aacf/providers/Microsoft.Authorization/roleDefinitions/33333333-3333-3333-3333-333333333333"
    }
  }
}

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
    condition     = azurerm_role_assignment.main[0].role_definition_name == "Contributor"
    error_message = "Role assignment should be Contributor"
  }

  # No custom_role, so no custom role definition and role_name echoes the built-in role.
  assert {
    condition     = length(azurerm_role_definition.custom) == 0
    error_message = "a built-in role must not create a custom role definition"
  }

  assert {
    condition     = output.role_name == "Contributor" && output.custom_role_id == null
    error_message = "expected role_name 'Contributor' and no custom role id, got ${output.role_name}"
  }

  # The application must be owned by the deploying identity: Application.ReadWrite.OwnedBy is scoped
  # to owned applications, so an ownerless app cannot be deleted by the identity that created it.
  assert {
    condition     = azuread_application.main.owners == toset(["22222222-2222-2222-2222-222222222222"])
    error_message = "application must default its owner to the deploying identity, got ${jsonencode(azuread_application.main.owners)}"
  }

  assert {
    condition     = azuread_service_principal.main.owners == toset(["22222222-2222-2222-2222-222222222222"])
    error_message = "service principal must default its owner to the deploying identity, got ${jsonencode(azuread_service_principal.main.owners)}"
  }
}

run "valid_reader_service_principal" {
  variables {
    display_name = "test-sp-reader"
    azure_role   = "Reader"
  }

  assert {
    condition     = azurerm_role_assignment.main[0].role_definition_name == "Reader"
    error_message = "Role assignment should be Reader"
  }
}

run "explicit_owners_override_the_default" {
  variables {
    display_name = "test-sp-owners"
    azure_role   = "Reader"
    owners       = ["44444444-4444-4444-4444-444444444441", "44444444-4444-4444-4444-444444444442"]
  }

  assert {
    condition     = azuread_application.main.owners == toset(["44444444-4444-4444-4444-444444444441", "44444444-4444-4444-4444-444444444442"])
    error_message = "explicit owners must replace the deploying identity, got ${jsonencode(azuread_application.main.owners)}"
  }
}

run "no_role_requested" {
  variables {
    display_name = "test-sp-no-role"
    azure_role   = null
  }

  assert {
    condition     = length(azurerm_role_assignment.main) == 0
    error_message = "no role assignment may be created when neither azure_role nor custom_role is set"
  }

  assert {
    condition     = output.role_assignment_id == null && output.role_name == null
    error_message = "role outputs must be null when no role was assigned"
  }
}

run "custom_role_takes_precedence" {
  variables {
    display_name = "test-sp-custom-role"
    azure_role   = "Reader"
    custom_role = {
      name        = "test-sp-custom"
      description = "Read blobs only"
      actions     = ["Microsoft.Storage/storageAccounts/read"]
    }
  }

  assert {
    condition     = length(azurerm_role_definition.custom) == 1
    error_message = "custom_role must create a role definition"
  }

  assert {
    condition     = azurerm_role_definition.custom[0].permissions[0].actions == tolist(["Microsoft.Storage/storageAccounts/read"])
    error_message = "custom role definition must carry the requested actions, got ${jsonencode(azurerm_role_definition.custom[0].permissions[0].actions)}"
  }

  # azure_role is set too, but custom_role wins: the assignment goes through the custom definition.
  assert {
    condition     = azurerm_role_assignment.main[0].role_definition_id == azurerm_role_definition.custom[0].role_definition_resource_id
    error_message = "custom_role must drive the assignment through role_definition_id, got ${azurerm_role_assignment.main[0].role_definition_id}"
  }

  assert {
    condition     = output.role_name == "test-sp-custom" && output.custom_role_id != null
    error_message = "role_name must echo the custom role, got ${output.role_name}"
  }
}

# Pins the semantics of the custom_role validation. It does not reproduce the defect that made this
# module undeployable: that needs a runtime evaluating both operands of ||, and both OpenTofu here
# and the version the BBD pins short-circuit, so dropping the try() guard still passes. The guard
# stays regardless — the runtime the BBD happens to pin is not this module's to assume.
run "custom_role_without_any_action_is_rejected" {
  # Variable validation fails before the apply stage, which tofu test reports as an overall failure
  # unless the run is plan-only. Same for the two secret_rotation_days runs below.
  command = plan

  variables {
    display_name = "test-sp-empty-custom-role"
    custom_role = {
      name = "test-sp-empty"
    }
  }

  expect_failures = [
    var.custom_role
  ]
}

run "custom_role_with_only_data_actions_is_accepted" {
  variables {
    display_name = "test-sp-data-actions"
    custom_role = {
      name         = "test-sp-data"
      data_actions = ["Microsoft.Storage/storageAccounts/blobServices/containers/blobs/read"]
    }
  }

  assert {
    condition     = length(azurerm_role_definition.custom) == 1
    error_message = "a custom role carrying only data_actions must be accepted"
  }
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

  assert {
    condition     = length(azuread_application_password.main) == 1
    error_message = "a client secret must be created when create_client_secret is true"
  }

  assert {
    condition     = output.authentication_method == "client_secret"
    error_message = "Authentication method should be client_secret"
  }
}

run "invalid_secret_rotation_too_short" {
  command = plan

  variables {
    display_name         = "test-sp-short-rotation"
    secret_rotation_days = 15
  }

  expect_failures = [
    var.secret_rotation_days
  ]
}

run "invalid_secret_rotation_too_long" {
  command = plan

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
    condition     = length(azuread_application_password.main) == 0 && length(time_rotating.secret_rotation) == 0
    error_message = "no client secret resources may exist when create_client_secret is false"
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
