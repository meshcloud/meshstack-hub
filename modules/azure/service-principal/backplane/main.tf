data "azurerm_subscription" "current" {}

# -----------------------------------------------------------------------------
# Automation principal for building block deployment
#
# A User-Assigned Managed Identity rather than an app registration: it needs no Entra
# Application.ReadWrite.All to create, it federates with meshStack's replicator out of the box, and
# it produces no secret to rotate. See ../../../../.agents/references/azure-backplane.md.
# -----------------------------------------------------------------------------

resource "azurerm_resource_group" "buildingblock_deploy" {
  name     = var.name
  location = var.location
}

resource "azurerm_user_assigned_identity" "buildingblock_deploy" {
  name                = var.name
  location            = var.location
  resource_group_name = azurerm_resource_group.buildingblock_deploy.name
}

resource "azurerm_federated_identity_credential" "buildingblock_deploy" {
  for_each = { for i, s in var.workload_identity_federation.subjects : tostring(i) => s }

  name                      = "subject-${each.key}"
  user_assigned_identity_id = azurerm_user_assigned_identity.buildingblock_deploy.id
  audience                  = ["api://AzureADTokenExchange"]
  issuer                    = var.workload_identity_federation.issuer
  subject                   = each.value
}

# -----------------------------------------------------------------------------
# Microsoft Graph API permissions
#
# Application.ReadWrite.OwnedBy lets the identity create applications and service principals, and
# fully manage the ones it owns. The building block records this identity as the owner of every
# application it creates, so this grant covers the whole lifecycle including deletion.
# -----------------------------------------------------------------------------

data "azuread_service_principal" "msgraph" {
  client_id = "00000003-0000-0000-c000-000000000000" # Microsoft Graph
}

resource "azuread_app_role_assignment" "msgraph_application_readwrite_ownedby" {
  app_role_id         = data.azuread_service_principal.msgraph.app_role_ids["Application.ReadWrite.OwnedBy"]
  principal_object_id = azurerm_user_assigned_identity.buildingblock_deploy.principal_id
  resource_object_id  = data.azuread_service_principal.msgraph.object_id
}

# -----------------------------------------------------------------------------
# Azure RBAC role definition and assignment
# The identity needs to assign roles to the service principals the building block creates.
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

      # Role Definitions (to look up built-in roles and create custom roles)
      "Microsoft.Authorization/roleDefinitions/read",
      "Microsoft.Authorization/roleDefinitions/write",
      "Microsoft.Authorization/roleDefinitions/delete",
    ]
  }

  assignable_scopes = [var.scope]
}

resource "azurerm_role_assignment" "buildingblock_deploy" {
  role_definition_id = azurerm_role_definition.buildingblock_deploy.role_definition_resource_id
  principal_id       = azurerm_user_assigned_identity.buildingblock_deploy.principal_id
  scope              = var.scope
}
