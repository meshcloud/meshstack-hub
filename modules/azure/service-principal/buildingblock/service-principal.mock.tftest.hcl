# Mocked unit tests: no Azure credentials, no Entra objects. These pin the module's wiring — which
# resources exist for a given input combination and what the outputs read — not that a deployment
# actually succeeds. The real apply lives in ../e2e.
#
# The azuread and azurerm providers validate object and role definition IDs even when mocked, so
# the defaults below have to be well-formed GUIDs rather than readable placeholders.

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

run "builtin_role" {
  variables {
    display_name = "test-sp-contributor"
    azure_role   = "Contributor"
    description  = "Test service principal with Contributor role"
  }

  assert {
    condition     = azuread_application.main.display_name == "test-sp-contributor" && azuread_application.main.description == "Test service principal with Contributor role"
    error_message = "application must carry the requested display name and description, got ${azuread_application.main.display_name} / ${azuread_application.main.description}"
  }

  assert {
    condition     = azurerm_role_assignment.main[0].role_definition_name == "Contributor"
    error_message = "role assignment should be Contributor, got ${azurerm_role_assignment.main[0].role_definition_name}"
  }

  # No custom_role, so no custom role definition and role_name echoes the built-in role.
  assert {
    condition     = length(azurerm_role_definition.custom) == 0 && output.role_name == "Contributor" && output.custom_role_id == null
    error_message = "a built-in role must not create a custom role definition, got role_name ${output.role_name}"
  }

  # The application must be owned by the deploying identity: Application.ReadWrite.OwnedBy is scoped
  # to owned applications, so an ownerless app cannot be deleted by the identity that created it.
  assert {
    condition     = azuread_application.main.owners == toset(["22222222-2222-2222-2222-222222222222"]) && azuread_service_principal.main.owners == toset(["22222222-2222-2222-2222-222222222222"])
    error_message = "application and service principal must default their owner to the deploying identity, got ${jsonencode(azuread_application.main.owners)} / ${jsonencode(azuread_service_principal.main.owners)}"
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
    condition     = length(azurerm_role_definition.custom) == 1 && azurerm_role_definition.custom[0].permissions[0].actions == tolist(["Microsoft.Storage/storageAccounts/read"])
    error_message = "custom_role must create a role definition carrying the requested actions, got ${jsonencode(azurerm_role_definition.custom[*].permissions)}"
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

run "client_secret_with_custom_rotation" {
  variables {
    display_name         = "test-sp-rotation"
    secret_rotation_days = 180
    create_client_secret = true
  }

  assert {
    condition     = time_rotating.secret_rotation[0].rotation_days == 180
    error_message = "secret rotation should be 180 days, got ${time_rotating.secret_rotation[0].rotation_days}"
  }

  assert {
    condition     = length(azuread_application_password.main) == 1 && output.authentication_method == "client_secret"
    error_message = "a client secret must be created when create_client_secret is true, got authentication_method ${output.authentication_method}"
  }
}

run "no_client_secret" {
  variables {
    display_name         = "test-sp-oidc"
    create_client_secret = false
  }

  assert {
    condition     = length(azuread_application_password.main) == 0 && length(time_rotating.secret_rotation) == 0
    error_message = "no client secret resources may exist when create_client_secret is false"
  }

  assert {
    condition     = output.client_secret == null && output.secret_expiration_date == null && output.authentication_method == "workload_identity_federation"
    error_message = "secret outputs must be null and the authentication method must be workload_identity_federation, got ${output.authentication_method}"
  }
}
