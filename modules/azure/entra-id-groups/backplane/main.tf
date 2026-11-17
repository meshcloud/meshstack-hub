resource "azurerm_resource_group" "this" {
  name     = var.name
  location = var.location
}

resource "azurerm_user_assigned_identity" "this" {
  name                = var.name
  location            = var.location
  resource_group_name = azurerm_resource_group.this.name
}

resource "azurerm_federated_identity_credential" "this" {
  for_each = { for i, s in var.workload_identity_federation.subjects : tostring(i) => s }

  name                      = "subject-${each.key}"
  user_assigned_identity_id = azurerm_user_assigned_identity.this.id
  audience                  = [var.workload_identity_federation.audience]
  issuer                    = var.workload_identity_federation.issuer
  subject                   = each.value
}

resource "azurerm_federated_identity_credential" "trusted_runner" {
  for_each = { for identity in var.trusted_runner_identities : identity.runner_uuid => identity }

  depends_on = [azurerm_federated_identity_credential.this]

  lifecycle {
    precondition {
      condition     = each.value.subject != null
      error_message = "No version of the building block definition uses the trusted runner ${each.key}. So the subject of its tokens is unknown. Remove the runner from meshstack.trusted_runner_refs for this definition. Either the definition has only a draft version, whose runner meshStack changes in place. Or other modules get the same list, and this definition never used the runner."
    }
  }

  name                      = "trusted-runner-${each.key}"
  user_assigned_identity_id = azurerm_user_assigned_identity.this.id
  audience                  = [each.value.audience]
  issuer                    = each.value.issuer
  subject                   = each.value.subject
}

# Grant Microsoft Graph app roles so the UAMI can read users, manage groups, and manage Administrative Unit members.
data "azuread_service_principal" "msgraph" {
  client_id = "00000003-0000-0000-c000-000000000000" # Microsoft Graph
}

resource "azuread_app_role_assignment" "user_read_all" {
  app_role_id         = data.azuread_service_principal.msgraph.app_role_ids["User.Read.All"]
  principal_object_id = azurerm_user_assigned_identity.this.principal_id
  resource_object_id  = data.azuread_service_principal.msgraph.object_id
}

resource "azuread_app_role_assignment" "group_readwrite_all" {
  app_role_id         = data.azuread_service_principal.msgraph.app_role_ids["Group.ReadWrite.All"]
  principal_object_id = azurerm_user_assigned_identity.this.principal_id
  resource_object_id  = data.azuread_service_principal.msgraph.object_id
}

resource "azuread_app_role_assignment" "administrative_unit_readwrite_all" {
  app_role_id         = data.azuread_service_principal.msgraph.app_role_ids["AdministrativeUnit.ReadWrite.All"]
  principal_object_id = azurerm_user_assigned_identity.this.principal_id
  resource_object_id  = data.azuread_service_principal.msgraph.object_id
}
