resource "azurerm_user_assigned_identity" "buildingblock" {
  name                = var.name
  location            = var.location
  resource_group_name = var.resource_group_name
}

resource "azurerm_federated_identity_credential" "buildingblock" {
  for_each = { for i, s in var.workload_identity_federation.subjects : tostring(i) => s }

  name                = "subject-${each.key}"
  resource_group_name = var.resource_group_name
  parent_id           = azurerm_user_assigned_identity.buildingblock.id
  audience            = ["api://AzureADTokenExchange"]
  issuer              = var.workload_identity_federation.issuer
  subject             = each.value
}

resource "azurerm_role_definition" "buildingblock_deploy" {
  name        = "${var.name}-deploy"
  description = "Enables deployment of the ${var.name} building block to subscriptions"
  scope       = var.scope

  permissions {
    actions = [
      # Register resource providers in Azure Resource Manager
      "*/register/action",

      # Budget
      "Microsoft.Consumption/budgets/*",

      # Resource Groups
      "Microsoft.Resources/subscriptions/resourceGroups/read",
      "Microsoft.Resources/subscriptions/providers/read",
    ]
  }
}

resource "azurerm_role_assignment" "buildingblock" {
  scope              = var.scope
  role_definition_id = azurerm_role_definition.buildingblock_deploy.role_definition_resource_id
  principal_id       = azurerm_user_assigned_identity.buildingblock.principal_id
}
