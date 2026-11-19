resource "azurerm_resource_group" "backplane" {
  name     = var.name
  location = var.location
}

resource "azurerm_user_assigned_identity" "backplane" {
  name                = var.name
  location            = var.location
  resource_group_name = azurerm_resource_group.backplane.name
}

resource "azurerm_federated_identity_credential" "backplane" {
  for_each = { for i, s in var.workload_identity_federation.subjects : tostring(i) => s }

  name                      = "subject-${each.key}"
  user_assigned_identity_id = azurerm_user_assigned_identity.backplane.id
  audience                  = [var.workload_identity_federation.audience]
  issuer                    = var.workload_identity_federation.issuer
  subject                   = each.value
}

resource "azurerm_federated_identity_credential" "trusted_runner" {
  for_each = { for identity in var.trusted_runner_identities : identity.runner_uuid => identity }

  depends_on = [azurerm_federated_identity_credential.backplane]

  lifecycle {
    precondition {
      condition     = each.value.subject != null
      error_message = "No version of the building block definition uses the trusted runner ${each.key}. So the subject of its tokens is unknown. Remove the runner from meshstack.additional_trusted_runner_refs for this definition. Either the definition has only a draft version, whose runner meshStack changes in place. Or other modules get the same list, and this definition never used the runner."
    }
  }

  name                      = "trusted-runner-${each.key}"
  user_assigned_identity_id = azurerm_user_assigned_identity.backplane.id
  audience                  = [each.value.audience]
  issuer                    = each.value.issuer
  subject                   = each.value.subject
}

resource "azurerm_role_definition" "backplane" {
  name        = "${var.name}-deploy"
  description = "Enables deployment of the ${var.name} building block to subscriptions"
  scope       = var.scope

  permissions {
    actions = [
      # Register resource providers in Azure Resource Manager
      "*/register/action",

      # Resource Groups - full lifecycle management
      "Microsoft.Resources/subscriptions/resourceGroups/*",

      # Read subscription providers
      "Microsoft.Resources/subscriptions/providers/read",
    ]
  }
}

resource "azurerm_role_assignment" "backplane" {
  scope              = var.scope
  role_definition_id = azurerm_role_definition.backplane.role_definition_resource_id
  principal_id       = azurerm_user_assigned_identity.backplane.principal_id
}
