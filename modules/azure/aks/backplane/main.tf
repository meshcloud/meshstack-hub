resource "azurerm_role_definition" "buildingblock_deploy" {
  name        = "${var.name}-deploy"
  scope       = var.scope
  description = "Enables deployment of the ${var.name} building block to subscriptions"

  permissions {
    actions = [
      "Microsoft.ContainerService/managedClusters/*",
      "Microsoft.ContainerService/managedClusters/accessProfiles/*",
      "Microsoft.Network/virtualNetworks/*",
      "Microsoft.Network/networkInterfaces/read",
      "Microsoft.Network/networkSecurityGroups/*",
      "Microsoft.Resources/deployments/*",
      "Microsoft.Resources/subscriptions/resourceGroups/*",
      "Microsoft.OperationalInsights/*",
      "Microsoft.Insights/diagnosticSettings/*",
      "Microsoft.Authorization/roleAssignments/read"
    ]
  }
}

resource "azurerm_role_assignment" "buildingblock_deploy" {
  for_each = var.principal_ids

  role_definition_id = azurerm_role_definition.buildingblock_deploy.role_definition_resource_id
  principal_id       = each.value
  scope              = var.scope
}
