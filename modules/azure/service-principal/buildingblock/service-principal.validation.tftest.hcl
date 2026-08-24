# Variable validation only. Kept apart from the mocked apply runs because these are plan-only:
# validation fails before the apply stage, which `tofu test` otherwise reports as an overall
# failure rather than as the expected failure.
#
# These pin the validation's *semantics*. They do not reproduce the defect that once made this
# module undeployable — that needs a runtime evaluating both operands of `||`, and OpenTofu
# short-circuits since 1.10, so dropping the `try()` guard in variables.tf still passes here. Only
# an e2e run against a runtime that does not short-circuit could catch that class of defect.

mock_provider "azuread" {
  mock_resource "azuread_application" {
    defaults = {
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

# Only the object ID matters here: the plan still evaluates the resources behind the failing
# validation, and the azuread provider rejects a non-GUID owner before the expected failure surfaces.
mock_provider "azurerm" {
  mock_data "azurerm_client_config" {
    defaults = {
      object_id = "22222222-2222-2222-2222-222222222222"
    }
  }
}

variables {
  display_name          = "test-service-principal"
  azure_subscription_id = "f808fff2-adda-415a-9b77-2833c041aacf"

  # Keeps azuread_application_password out of the graph, so the mocks need no parseable resource IDs.
  create_client_secret = false
}

run "custom_role_without_any_action_is_rejected" {
  command = plan

  variables {
    custom_role = {
      name = "test-sp-empty"
    }
  }

  expect_failures = [
    var.custom_role
  ]
}

run "secret_rotation_below_the_floor_is_rejected" {
  command = plan

  variables {
    secret_rotation_days = 15
  }

  expect_failures = [
    var.secret_rotation_days
  ]
}

run "secret_rotation_above_the_ceiling_is_rejected" {
  command = plan

  variables {
    secret_rotation_days = 800
  }

  expect_failures = [
    var.secret_rotation_days
  ]
}
