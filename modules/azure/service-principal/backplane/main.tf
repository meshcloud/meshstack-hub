data "azurerm_subscription" "current" {}

# -----------------------------------------------------------------------------
# Service Principal for Building Block Deployment
# -----------------------------------------------------------------------------

resource "azuread_application" "buildingblock_deploy" {
  count = var.create_service_principal_name != null ? 1 : 0

  display_name = "${var.name}-${var.create_service_principal_name}"

  required_resource_access {
    resource_app_id = "00000003-0000-0000-c000-000000000000" # Microsoft Graph

    resource_access {
      id   = "18a4783c-866b-4cc7-a460-3d5e5662c884" # Application.ReadWrite.OwnedBy
      type = "Role"
    }
  }
}

resource "azuread_service_principal" "buildingblock_deploy" {
  count = var.create_service_principal_name != null ? 1 : 0

  client_id                    = azuread_application.buildingblock_deploy[0].client_id
  app_role_assignment_required = false
}

resource "azuread_application_federated_identity_credential" "buildingblock_deploy" {
  count = var.create_service_principal_name != null && var.workload_identity_federation != null ? 1 : 0

  application_id = azuread_application.buildingblock_deploy[0].id
  display_name   = var.create_service_principal_name
  audiences      = ["api://AzureADTokenExchange"]
  issuer         = var.workload_identity_federation.issuer
  subject        = var.workload_identity_federation.subject
}

resource "azuread_application_password" "buildingblock_deploy" {
  count = var.create_service_principal_name != null && var.workload_identity_federation == null ? 1 : 0

  application_id = azuread_application.buildingblock_deploy[0].id
  display_name   = "${var.create_service_principal_name}-password"
}

# -----------------------------------------------------------------------------
# Microsoft Graph API Permissions
# The service principal needs to create Azure AD applications and service principals.
# We grant Application.ReadWrite.OwnedBy which allows creating apps and managing
# apps that this service principal owns.
# -----------------------------------------------------------------------------

data "azuread_service_principal" "msgraph" {
  client_id = "00000003-0000-0000-c000-000000000000" # Microsoft Graph
}

resource "azuread_app_role_assignment" "msgraph_application_readwrite_ownedby" {
  count = var.create_service_principal_name != null ? 1 : 0

  app_role_id         = data.azuread_service_principal.msgraph.app_role_ids["Application.ReadWrite.OwnedBy"]
  principal_object_id = azuread_service_principal.buildingblock_deploy[0].object_id
  resource_object_id  = data.azuread_service_principal.msgraph.object_id
}

# Grant the same permissions to existing principals
resource "azuread_app_role_assignment" "msgraph_application_readwrite_ownedby_existing" {
  for_each = var.existing_principal_ids

  app_role_id         = data.azuread_service_principal.msgraph.app_role_ids["Application.ReadWrite.OwnedBy"]
  principal_object_id = each.value
  resource_object_id  = data.azuread_service_principal.msgraph.object_id
}

# -----------------------------------------------------------------------------
# Azure RBAC Role Definition and Assignments
# The service principal needs to assign roles to created service principals
# on target subscriptions.
# -----------------------------------------------------------------------------

resource "azurerm_role_definition" "buildingblock_deploy" {
  name        = "${var.name}-deploy"
  scope       = var.scope
  description = "Enables deployment of the ${var.name} building block to subscriptions"

  permissions {
    actions = [
      # Role Assignments (to assign roles to created service principals)
      "Microsoft.Authorization/roleAssignments/read",
      "Microsoft.Authorization/roleAssignments/write",
      "Microsoft.Authorization/roleAssignments/delete",

      # Read role definitions (to look up built-in roles like Contributor)
      "Microsoft.Authorization/roleDefinitions/read",
    ]
  }

  assignable_scopes = [var.scope]
}

resource "azurerm_role_assignment" "existing_principals" {
  for_each = var.existing_principal_ids

  role_definition_id = azurerm_role_definition.buildingblock_deploy.role_definition_resource_id
  principal_id       = each.value
  scope              = var.scope
}

resource "azurerm_role_assignment" "created_principal" {
  count = var.create_service_principal_name != null ? 1 : 0

  role_definition_id = azurerm_role_definition.buildingblock_deploy.role_definition_resource_id
  principal_id       = azuread_service_principal.buildingblock_deploy[0].object_id
  scope              = var.scope
}
