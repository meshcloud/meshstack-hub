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

  name                = "subject-${each.key}"
  resource_group_name = azurerm_resource_group.backplane.name
  parent_id           = azurerm_user_assigned_identity.backplane.id
  audience            = ["api://AzureADTokenExchange"]
  issuer              = var.workload_identity_federation.issuer
  subject             = each.value
}

# Grant Microsoft Graph app roles so the UAMI can read users, manage groups, and manage Administrative Unit members.
data "azuread_service_principal" "msgraph" {
  client_id = "00000003-0000-0000-c000-000000000000" # Microsoft Graph
}

resource "azuread_app_role_assignment" "user_read_all" {
  app_role_id         = data.azuread_service_principal.msgraph.app_role_ids["User.Read.All"]
  principal_object_id = azurerm_user_assigned_identity.backplane.principal_id
  resource_object_id  = data.azuread_service_principal.msgraph.object_id
}

resource "azuread_app_role_assignment" "group_readwrite_all" {
  app_role_id         = data.azuread_service_principal.msgraph.app_role_ids["Group.ReadWrite.All"]
  principal_object_id = azurerm_user_assigned_identity.backplane.principal_id
  resource_object_id  = data.azuread_service_principal.msgraph.object_id
}

resource "azuread_app_role_assignment" "administrative_unit_readwrite_all" {
  app_role_id         = data.azuread_service_principal.msgraph.app_role_ids["AdministrativeUnit.ReadWrite.All"]
  principal_object_id = azurerm_user_assigned_identity.backplane.principal_id
  resource_object_id  = data.azuread_service_principal.msgraph.object_id
}
